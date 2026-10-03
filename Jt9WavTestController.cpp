#include "Jt9WavTestController.hpp"

#include <QAbstractButton>
#include <QAction>
#include <QApplication>
#include <QFileInfo>
#include <QSpinBox>
#include <cstdlib>
#include <iostream>
#include <utility>

#include "widgets/mainwindow.h"

Jt9WavTestController::Jt9WavTestController (
    MainWindow * window, QString wavPath, QString expectedMessage, QObject * parent)
  : QObject {parent}
  , m_window {window}
  , m_wavPath {std::move (wavPath)}
  , m_expectedMessage {expectedMessage.simplified ()}
{
  m_timeout.setSingleShot (true);
  m_timeout.setInterval (60000);
  connect (&m_timeout, &QTimer::timeout, this, [this] {
    finish (tr ("Timed out waiting for JT9 WAV decoding."));
  });
  m_prepareTimer.setSingleShot (true);
  connect (&m_prepareTimer, &QTimer::timeout,
           this, &Jt9WavTestController::prepareWhenReady);
  m_modalTimer.setInterval (100);
  connect (&m_modalTimer, &QTimer::timeout, this, [this] {
    if (auto * modal = QApplication::activeModalWidget ())
      finish (tr ("Unexpected modal window: %1").arg (modal->windowTitle ()));
  });
  connect (m_window, &MainWindow::decoderBackendFailed, this,
           [this] (QString const& reason) {
    finish (tr ("Decoder backend failed: %1").arg (reason));
  });
  connect (m_window, &MainWindow::decoderBackendStarted, this, [this] {
    if (m_started) finish (tr ("Decoder backend restarted during the test."));
  });
  connect (m_window, &MainWindow::decodeCycleAborted, this, [this] {
    finish (tr ("JT9 decode cycle was aborted."));
  });
  connect (m_window, &MainWindow::decodeCycleStarted, this,
           [this] (quint64 generation) {
    if (m_finished) return;
    if (!m_awaitingCycle || m_activeGeneration || generation <= m_lastGeneration)
      {
        finish (tr ("Unexpected JT9 decode cycle %1.").arg (generation));
        return;
      }
    m_awaitingCycle = false;
    m_activeGeneration = generation;
    m_observed = false;
  });
  connect (m_window, &MainWindow::decodedMessageDisplayed, this,
           [this] (QString const& message) {
    if (m_activeGeneration && message.simplified () == m_expectedMessage)
      m_observed = true;
  });
  connect (m_window, &MainWindow::decodeCycleCompleted,
           this, &Jt9WavTestController::completeCycle);
}

void Jt9WavTestController::begin ()
{
  if (!QFileInfo {m_wavPath}.isFile () || m_expectedMessage.isEmpty ())
    {
      finish (tr ("A WAV file and an expected message are required."));
      return;
    }
  m_timeout.start ();
  m_modalTimer.start ();
  prepareWhenReady ();
}

void Jt9WavTestController::prepareWhenReady ()
{
  if (m_finished || m_started) return;
  auto * jt9 = m_window->findChild<QAction *> ("actionJT9");
  auto * quick = m_window->findChild<QAction *> ("actionQuickDecode");
  auto * submode = m_window->findChild<QSpinBox *> ("sbSubmode");
  auto * fast = m_window->findChild<QAbstractButton *> ("cbFast9");
  auto * cqOnly = m_window->findChild<QAbstractButton *> ("cbCQonly");
  auto * decode = m_window->findChild<QAbstractButton *> ("DecodeButton");
  if (!jt9 || !quick || !submode || !fast || !cqOnly || !decode)
    {
      finish (tr ("A required JT9 GUI control was not found."));
      return;
    }
  if (!m_window->decoderBackendRunning () || m_window->decoderBusy ()
      || !jt9->isEnabled () || !decode->isEnabled ())
    {
      m_prepareTimer.start (50);
      return;
    }
  if (!m_configured)
    {
      jt9->trigger ();
      quick->trigger ();
      submode->setValue (0);
      if (fast->isChecked ()) fast->click ();
      cqOnly->setChecked (false);
      m_configured = true;
      m_prepareTimer.start (100);
      return;
    }
  if (!jt9->isChecked () || !quick->isChecked ()
      || submode->value () != 0 || fast->isChecked ()
      || !m_window->configureLiveAudioTestDecodeRange ())
    {
      finish (tr ("Unable to configure ordinary JT9A decoding."));
      return;
    }
  m_started = true;
  m_awaitingCycle = true;
  if (!m_window->startJt9WavTest (m_wavPath))
    finish (tr ("Unable to start the JT9 WAV load."));
}

void Jt9WavTestController::completeCycle (quint64 generation)
{
  if (m_finished) return;
  if (!m_activeGeneration || generation != m_activeGeneration || !m_observed)
    {
      finish (tr ("Cycle %1 did not display the expected message: %2")
              .arg (generation).arg (m_expectedMessage));
      return;
    }
  m_lastGeneration = generation;
  m_activeGeneration = 0;
  ++m_completedCycles;
  // Completion is emitted before MainWindow enables the Decode button.
  QTimer::singleShot (0, this, [this] {
    if (m_finished) return;
    auto * decode = m_window->findChild<QAbstractButton *> ("DecodeButton");
    if (m_window->decoderBusy () || !m_window->diskDataActive ()
        || !decode || !decode->isEnabled ())
      {
        finish (tr ("JT9 decoding did not return to an idle disk-data state."));
        return;
      }
    if (m_completedCycles == 2)
      {
        finish ();
        return;
      }
    m_observed = false;
    m_awaitingCycle = true;
    decode->click ();
  });
}

void Jt9WavTestController::finish (QString const& error)
{
  if (m_finished) return;
  m_finished = true;
  m_succeeded = error.isEmpty () && m_completedCycles == 2;
  m_timeout.stop ();
  m_prepareTimer.stop ();
  m_modalTimer.stop ();
  if (m_succeeded)
    std::cerr << "WSJT-X JT9 WAV test passed: initial and repeat decode displayed "
              << m_expectedMessage.toStdString () << std::endl;
  else
    std::cerr << "WSJT-X JT9 WAV test failed: " << error.toStdString ()
              << " completed_cycles=" << m_completedCycles << std::endl;
  if (auto * modal = QApplication::activeModalWidget ()) modal->close ();
  m_window->close ();
  QCoreApplication::exit (m_succeeded ? EXIT_SUCCESS : EXIT_FAILURE);
}
