#include "WavDecodeTestController.hpp"

#include <QAbstractButton>
#include <QAction>
#include <QApplication>
#include <QFileInfo>
#include <QSpinBox>
#include <cstdlib>
#include <iostream>
#include <utility>

#include "widgets/mainwindow.h"

WavDecodeTestController::WavDecodeTestController (
    MainWindow * window, QString wavPath, QString expectedMessage, Mode mode, QObject * parent)
  : QObject {parent}
  , m_window {window}
  , m_mode {mode}
  , m_modeName {mode == Mode::Jt9 ? QStringLiteral ("JT9") : QStringLiteral ("JT65")}
  , m_wavPath {std::move (wavPath)}
  , m_expectedMessage {expectedMessage.simplified ()}
{
  m_timeout.setSingleShot (true);
  m_timeout.setInterval (60000);
  connect (&m_timeout, &QTimer::timeout, this, [this] {
    finish (tr ("Timed out waiting for %1 WAV decoding.").arg (m_modeName));
  });
  m_prepareTimer.setSingleShot (true);
  connect (&m_prepareTimer, &QTimer::timeout,
           this, &WavDecodeTestController::prepareWhenReady);
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
    finish (tr ("%1 decode cycle was aborted.").arg (m_modeName));
  });
  connect (m_window, &MainWindow::decodeCycleStarted, this,
           [this] (quint64 generation) {
    if (m_finished) return;
    if (!m_awaitingCycle || m_activeGeneration || generation <= m_lastGeneration)
      {
        finish (tr ("Unexpected %1 decode cycle %2.").arg (m_modeName).arg (generation));
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
           this, &WavDecodeTestController::completeCycle);
}

void WavDecodeTestController::begin ()
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

void WavDecodeTestController::prepareWhenReady ()
{
  if (m_finished || m_started) return;
  auto * mode = m_window->findChild<QAction *> (
      m_mode == Mode::Jt9 ? "actionJT9" : "actionJT65");
  auto * quick = m_window->findChild<QAction *> ("actionQuickDecode");
  auto * submode = m_window->findChild<QSpinBox *> ("sbSubmode");
  auto * fast = m_window->findChild<QAbstractButton *> ("cbFast9");
  auto * cqOnly = m_window->findChild<QAbstractButton *> ("cbCQonly");
  auto * frequency = m_window->findChild<QSpinBox *> ("RxFreqSpinBox");
  auto * decode = m_window->findChild<QAbstractButton *> ("DecodeButton");
  if (!mode || !quick || !submode || !fast || !cqOnly || !frequency || !decode)
    {
      finish (tr ("A required %1 GUI control was not found.").arg (m_modeName));
      return;
    }
  if (!m_window->decoderBackendRunning () || m_window->decoderBusy ()
      || !mode->isEnabled () || !decode->isEnabled ())
    {
      m_prepareTimer.start (50);
      return;
    }
  if (!m_configured)
    {
      mode->trigger ();
      quick->trigger ();
      submode->setValue (0);
      if (fast->isChecked ()) fast->click ();
      cqOnly->setChecked (false);
      frequency->setValue (1500);
      m_configured = true;
      m_prepareTimer.start (100);
      return;
    }
  if (!mode->isChecked () || !quick->isChecked ()
      || submode->value () != 0 || fast->isChecked ()
      || !m_window->configureLiveAudioTestDecodeRange ())
    {
      finish (tr ("Unable to configure ordinary %1A decoding.").arg (m_modeName));
      return;
    }
  m_started = true;
  m_awaitingCycle = true;
  if (!m_window->startWavDecodeTest (m_wavPath))
    finish (tr ("Unable to start the %1 WAV load.").arg (m_modeName));
}

void WavDecodeTestController::completeCycle (quint64 generation)
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
        finish (tr ("%1 decoding did not return to an idle disk-data state.").arg (m_modeName));
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

void WavDecodeTestController::finish (QString const& error)
{
  if (m_finished) return;
  m_finished = true;
  m_succeeded = error.isEmpty () && m_completedCycles == 2;
  m_timeout.stop ();
  m_prepareTimer.stop ();
  m_modalTimer.stop ();
  if (m_succeeded)
    std::cerr << "WSJT-X " << m_modeName.toStdString () << " WAV test passed: initial and repeat decode displayed "
              << m_expectedMessage.toStdString () << std::endl;
  else
    std::cerr << "WSJT-X " << m_modeName.toStdString () << " WAV test failed: " << error.toStdString ()
              << " completed_cycles=" << m_completedCycles << std::endl;
  if (auto * modal = QApplication::activeModalWidget ()) modal->close ();
  m_window->close ();
  QCoreApplication::exit (m_succeeded ? EXIT_SUCCESS : EXIT_FAILURE);
}
