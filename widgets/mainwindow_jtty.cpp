#include "mainwindow.h"
#include "ui_mainwindow.h"
#include "widegraph.h"
#include "commons.h"
#include "JttyMessages.hpp"
#include "JttyN1mm.hpp"
#include "JttyReceiveLine.hpp"
#include "Logger.hpp"
#include "models/DecodeHighlightingModel.hpp"
#include <QByteArray>
#include <QDateTime>
#include <QSettings>
#include "Modulator/Modulator.hpp"
#include <vector>
#ifdef WIN32
#include "MMTTYIF.hpp"
#undef MessageBox
#endif


extern qint32 g_iptt;

namespace
{
  Jtty::NativeExchangeProfile jttyExchangeProfile(Configuration const& configuration)
  {
    switch (configuration.special_op_id()) {
    case Configuration::SpecialOperatingActivity::FIELD_DAY:
      return Jtty::NativeExchangeProfile::FieldDay;
    case Configuration::SpecialOperatingActivity::RTTY:
      return Jtty::NativeExchangeProfile::RttyRoundup;
    default:
      return Jtty::NativeExchangeProfile::None;
    }
  }

  Jtty::NativeMacroContext jttyNativeMacroContext(
      Configuration const& configuration, QString const& hisCall, int serialNumber,
      int snr)
  {
    Jtty::NativeMacroContext context;
    context.myCall = configuration.my_callsign();
    context.hisCall = hisCall;
    context.serialNumber = serialNumber;
    context.grid = configuration.my_grid();
    context.snr = snr;
    context.exchangeProfile = jttyExchangeProfile(configuration);

    switch (context.exchangeProfile) {
    case Jtty::NativeExchangeProfile::FieldDay:
      context.configuredExchange = Jtty::normalizedFieldDayExchange(
        configuration.Field_Day_Exchange());
      break;
    case Jtty::NativeExchangeProfile::RttyRoundup:
      context.configuredExchange = configuration.RTTY_Exchange();
      break;
    default:
      break;
    }
    return context;
  }

  QString jttyNativeEncodeError(int status)
  {
    if (status == static_cast<int>(Jtty::NativeEncodeStatus::UnknownSection)) {
      return QStringLiteral("Field Day section is not registered in the ARRL/RAC table");
    }
    return QStringLiteral("native atom encoding failed");
  }
}

#define FCL fortran_charlen_t

extern "C" {
  void genjtty_profile_(char * msg, int const* exchange_profile,
                       int itone[], int* nsym, fortran_charlen_t);
  void genjtty_atoms_c(Jtty::NativeAtomDescriptor const atoms[], int natoms,
                       int itone[], int* nsym, int* status);

  void gen_jttywave_(int itone[], int* nsym, int* nsps, float* bt, float* fsample, float* f0,
                    float xjunk[], float wave[], int* icmplx, int* nwave);
}

#ifdef WIN32
static QString append_separator(QString message) {
    if (!message.isEmpty()) {
        QChar lastChar = message.at(message.length() - 1);
        if (lastChar != '\r' && lastChar != '\n' && lastChar != ' ') {
            message += "\r\n";
        }
    }
    return message;
}
#endif



void MainWindow::updateJttyDecodeHeadings()
{
  QString const prefix = ui->cbIncludeTime->isChecked()
    ? QStringLiteral("  UTC  Freq  dB  ") : QStringLiteral("Freq  dB  ");
  ui->lh_decodes_headings_label->setText(prefix + tr ("Message"));
  ui->rh_decodes_headings_label->setText(prefix + tr ("Message"));
}

void MainWindow::on_cbIncludeTime_toggled(bool)
{
  if (m_mode == "JTTY") {
    updateJttyDecodeHeadings();
    refreshJttyReceiveLines();
  }
}

void MainWindow::jtty_tx(QString message)
{
  // Render and enqueue immediately; the shared transmit buffer chains messages
  // gaplessly while playback is underway.
  submitJttyText(message);
}

qint64 MainWindow::submitJttyText(QString message)
{
  qint64 const requestId = ++m_jttyTxRequestId;
  execute_jtty_tx(requestId, message);
  return requestId;
}

void MainWindow::submitJttyDraft(QString message)
{
  if (m_jttyDraftAcceptanceTracker.hasPendingSubmissionForCurrentDraft ()) {
    ui->Tx_Message->selectAll ();
    return;
  }

  qint64 const requestId = ++m_jttyTxRequestId;
  m_jttyDraftAcceptanceTracker.trackSubmission (requestId);
  execute_jtty_tx (requestId, message);
  if (m_jttyDraftAcceptanceTracker.isPending (requestId)) {
    ui->Tx_Message->selectAll ();
  }
}

void MainWindow::execute_jtty_tx(qint64 requestId, QString message)
{
  int itone[944];
  // Captured before anything below can change m_jttyTxActive: true means
  // this message is being queued behind one still transmitting, not
  // starting a fresh session.
  bool const isChainedMessage = m_jttyTxActive;
  if(ui->cbLowerCase->isChecked()) message = message.toLower();

  auto const preparedMessage = Jtty::prepareTransmitText(message);
  if (preparedMessage.changed()) {
    LOG_WARN("JTTY transmit message was normalized or shortened before encoding");
  }
  message = preparedMessage.text;
  if (message.isEmpty()) {
    Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::Empty);
    return;
  }

  // Keep message as the logical text; the chained leading space is only
  // transport spacing and must not leak into logging, display, or the contest
  // serial check in completeJttyTxEnqueue.
  auto transmitFrame = Jtty::transmitFrame(message, isChainedMessage).toLatin1();

  int nsym=0;
  int const exchangeProfile = static_cast<int>(jttyExchangeProfile(m_config));
  genjtty_profile_(transmitFrame.data(), &exchangeProfile,
                   &itone[0], &nsym, (FCL)80);
  if (nsym <= 0) {
    LOG_WARN("JTTY transmit message could not be encoded");
    Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::EncodingFailed);
    return;
  }

  message = QString::fromLatin1(transmitFrame).trimmed();
  execute_jtty_tones(requestId, message, itone, nsym);
}

void MainWindow::execute_jtty_tones(qint64 requestId, QString const& message,
                                    int const itone[], int nsym)
{
  if (jttyDrainInProgress()) {
    Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::NotAvailable);
    return;
  }
  m_nsym_jtty=nsym;

  int nsps4=4*384;
  float bt=2.0;
  float fsample=48000.0;
  float f0=ui->TxFreqSpinBox_2->value ();
  int icmplx=0;
  int nwave=nsps4*m_nsym_jtty;

  bool const newSession = !m_jttyTxActive;
  if (newSession) {
    advanceJttyTxQueueEpoch();
    m_jttyTxUsesTciAudio = m_tci_audio;
  }
  bool const useTciAudio = m_jttyTxUsesTciAudio;

  std::vector<float> wave(nwave > 0 ? nwave : 1);
  gen_jttywave_(const_cast<int *>(itone), &m_nsym_jtty, &nsps4, &bt, &fsample, &f0,
                wave.data(), wave.data(), &icmplx, &nwave);

  QVector<qint16> samples;
  samples.reserve(nwave);
  for(int i=0; i<nwave; ++i) {
    float v = wave[i] * 32767.0f;
    if(v >  32767.0f) v =  32767.0f;
    if(v < -32768.0f) v = -32768.0f;
    samples.append(static_cast<qint16>(qRound(v)));
  }
  if (samples.isEmpty()) {
    Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::EncodingFailed);
    return;
  }

  if (newSession) {
    // A fresh JTTY session starts a new FIFO accounting baseline even after a
    // natural drain, so drain totals remain session-relative.
    if (useTciAudio) {
      Q_EMIT m_config.transceiver_clear_jtty_pcm(m_jttyTxQueueEpoch);
    } else {
      m_jttyTxQueue->clear(m_jttyTxQueueEpoch);
    }
  }

  bool enqueued {false};
  TxAudioQueueProgress enqueueProgress;
  if(useTciAudio) {
    // TCI enqueue is asynchronous. MainWindow can reject a message that can
    // never fit; backend occupancy failures reject only the submitted enqueue.
    if (samples.size () <= TxAudioQueue::defaultCapacity ()) {
      QByteArray bytes(reinterpret_cast<char const *> (samples.constData ()),
                       samples.size () * int (sizeof (qint16)));
      qint64 const enqueueId = ++m_jttyTciEnqueueId;
      m_pendingJttyTciMessages.append(PendingJttyTciMessage {
        m_jttyTxQueueEpoch,
        enqueueId,
        requestId,
        samples.size (),
        message,
        newSession
      });
      m_jttyTxActive = true;
      Q_EMIT m_config.transceiver_enqueue_jtty_pcm(bytes, m_jttyTxQueueEpoch,
                                                   enqueueId);
      return;
    } else {
      LOG_WARN("JTTY TCI transmit FIFO capacity precheck failed; rejecting PCM enqueue");
      Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::QueueFull);
    }
  } else {
    auto const result = m_jttyTxQueue->enqueue(samples, m_jttyTxQueueEpoch);
    enqueued = result.accepted;
    enqueueProgress = result.progress;
    if (!enqueued) {
      LOG_WARN("JTTY transmit FIFO overflow; rejecting PCM enqueue");
    }
  }

  if (!enqueued) {
    if (!useTciAudio) {
      Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::QueueFull);
    }
    if (newSession) {
      advanceJttyTxQueueEpoch();
    }
    return;
  }

  completeJttyTxEnqueue(requestId, message, enqueueProgress, newSession, useTciAudio);
}

void MainWindow::advanceJttyTxQueueEpoch()
{
  m_jttyTxQueueEpoch = TxAudioQueueEpoch {m_jttyTxQueueEpoch.value () + 1};
  m_jttyTxQueueProgress = {};
  m_jttyTxQueueProgress.epoch = m_jttyTxQueueEpoch;
}

qint64 MainWindow::jttyTxCommittedSamples() const
{
  return m_jttyTxQueueProgress.total_samples;
}

void MainWindow::completeJttyTxEnqueue(qint64 requestId, QString const& message,
                                       TxAudioQueueProgress progress,
                                       bool newSession, bool useTciAudio)
{
  if (newSession) {
    beginTxEvidenceSession ();
  }
  m_currentMessage = message;
  qint64 const endSample = progress.total_samples;
  recordAcceptedJttyTextRequest(requestId, endSample);
  m_jttyTxQueueProgress = progress;
  if (m_txEvidenceGeneration.isValid () &&
      m_txEvidenceSourceSession == m_txEvidenceSession) {
    m_txPlaybackDiagnostics.commitTarget (m_txEvidenceSession,
                                           m_txEvidenceGeneration,
                                           progress.total_samples - 1, false);
    auto const sessionId = m_txEvidenceSession;
    auto const generation = m_txEvidenceGeneration;
    auto const totalSamples = progress.total_samples;
    QTimer::singleShot (0, this, [this, sessionId, generation, totalSamples] {
      LOG_INFO (QString ("TX playout evidence JTTY target commit session=%1 generation=%2 total=%3\n%4")
                .arg (sessionId.value ()).arg (generation.value ())
                .arg (totalSamples).arg (m_txPlaybackDiagnostics.diagnosticDump ()));
    });
  }
  m_jttyTxActive = true;
  m_transmitting = true;
  write_all("Tx", message);
  Q_EMIT jttyTextAccepted(requestId);

  // Tracked via JttyReceiveLine (not a one-off insert) so "Include Time" toggles still reach it.
  auto const resolved = DecodeHighlightingModel::resolve_colors(
    m_config.decode_highlighting().items(), {DecodeHighlightingModel::Highlight::Tx},
    QColor(Qt::yellow), QColor(Qt::black));
  JttyReceiveLine::Presentation const presentation {
    0, requestId, QDateTime::currentDateTimeUtc(), 0.0,
    ui->TxFreqSpinBox_2->value(), message, -10, true,
    resolved.background_, resolved.foreground_};
  JttyReceiveLine::Options const options {
    ui->cbLowerCase->isChecked(), ui->cbIncludeTime->isChecked()};
  JttyReceiveLine txLine;
  auto const cursor = txLine.render(*ui->decodedTextBrowser2->document(), presentation,
                                    options, ui->decodedTextBrowser2->contentFont());
  if (!cursor.isNull()) {
    ui->decodedTextBrowser2->setTextCursor(cursor);
    ui->decodedTextBrowser2->ensureCursorVisible();
  }

  handleJttyContestSerial(message);

  // Fault-detector watchdog: generous margin over all audio still to play (the
  // whole queued session, not just this message). The happy path completes via
  // the backend drain signal well before this fires.
  qint64 const pendingSamples = useTciAudio
    ? progress.total_samples : progress.queued_samples;
  int pendingMs = int(pendingSamples / 48);
  startJttyTxWatchdog(pendingMs + 1000 * m_config.txDelay() + 10000);

  monitor(false);

#ifdef WIN32
  if (m_mmttyif) {
    m_mmttyif->report_ptt_state(true);
  }
#endif

#ifdef WIN32
  if (m_mmttyif) {
    m_mmttyif->echo_message_to_n1mm(append_separator(message));
  }
#endif

  // Only a new session starts transmit; a message appended to an already-active
  // session chains gaplessly (soundcard) via the enqueue above. When PTT is not
  // yet up, guiUpdate keys it and ptt1Timer -> startTx2 -> transmit starts the
  // stream with the normal lead.
  if (newSession && g_iptt == 1 && !m_modulator->isActive()) {
    startTx2();
  }
}

void MainWindow::recordAcceptedJttyTextRequest(qint64 requestId, qint64 endSample)
{
  m_acceptedJttyTxRequests.append(AcceptedJttyTxRequest {
    m_jttyTxQueueEpoch,
    requestId,
    endSample
  });
}

QVector<qint64> MainWindow::takeCompletedJttyTextRequests(
  TxAudioQueueEpoch epoch, qint64 totalAtDrain)
{
  // Backends report only final drain, so per-text completion is observed when
  // the accepted text's containing JTTY session has drained.
  QVector<qint64> completedRequestIds;
  for (int i = 0; i < m_acceptedJttyTxRequests.size ();) {
    auto const accepted = m_acceptedJttyTxRequests.at (i);
    if (accepted.epoch == epoch && accepted.endSample <= totalAtDrain) {
      completedRequestIds.append(accepted.requestId);
      m_acceptedJttyTxRequests.remove (i);
    } else {
      ++i;
    }
  }
  return completedRequestIds;
}

void MainWindow::clearAcceptedJttyTextRequests(TxAudioQueueEpoch epoch)
{
  for (int i = 0; i < m_acceptedJttyTxRequests.size ();) {
    if (m_acceptedJttyTxRequests.at (i).epoch == epoch) {
      m_acceptedJttyTxRequests.remove (i);
    } else {
      ++i;
    }
  }
}

void MainWindow::handleJttyContestSerial(QString const& message)
{
  if(message.left(3).compare("TU ", Qt::CaseInsensitive) == 0) {
    logQSOTimer.start(0);
    int nr = ui->sbSerialNumber_2->value();
    m_xSent = QString::number(nr);
    ui->sbSerialNumber_2->setValue(nr+1);
  }
}

void MainWindow::abort_jtty_tx()
{
   noteTxStopReason (TxEvidence::TxStopReason::UserHalt);
   interruptJttyTx();

#ifdef WIN32
   if (m_mmttyif) {
       m_mmttyif->report_ptt_state(false);
   }
#endif

   stopTx();
}

void MainWindow::interruptJttyTx()
{
  if (m_mode != "JTTY" || !m_jttyTxActive) {
    return;
  }

  auto const interruptedEpoch = m_jttyTxQueueEpoch;
  if (!m_jttyTxUsesTciAudio) {
    auto const progress = m_jttyTxQueue->progress ();
    captureJttyTxEvidenceTotals (progress.served_samples,
                                 progress.total_samples,
                                 QStringLiteral ("JTTY source totals captured before abort"));
  } else {
    captureJttyTxEvidenceTotals (-1, m_jttyTxQueueProgress.total_samples,
                                 QStringLiteral ("TCI JTTY committed total captured before abort"));
  }
  advanceJttyTxQueueEpoch();
  clearAcceptedJttyTextRequests(interruptedEpoch);
  rejectPendingJttyTciMessages(JttyTxRejectReason::Aborted);
  m_pendingJttyTciMessages.clear();
  if (m_jttyTxUsesTciAudio) {
    Q_EMIT m_config.transceiver_clear_jtty_pcm(m_jttyTxQueueEpoch);
  } else {
    m_jttyTxQueue->clear(m_jttyTxQueueEpoch);
  }
  resetJttyTxState();
}

void MainWindow::onJttyBackendDrained(TxAudioQueueDrainState drain)
{
  if (m_mode != "JTTY" || !m_jttyTxActive) {
    return;
  }

  if (drain.epoch != m_jttyTxQueueEpoch
      || drain.total_at_drain != jttyTxCommittedSamples ()) {
    return;
  }

  qint64 const servedAtDrain = m_jttyTxUsesTciAudio
    ? drain.total_at_drain : m_jttyTxQueue->progress ().served_samples;
  captureJttyTxEvidenceTotals (servedAtDrain, drain.total_at_drain,
                               QStringLiteral ("JTTY source totals captured at drain"));

  auto const completedRequestIds = takeCompletedJttyTextRequests(
    drain.epoch, drain.total_at_drain);
  resetJttyTxState();
  stopTx();
  for (auto const requestId : completedRequestIds) {
    Q_EMIT jttyTextCompleted(requestId);
  }
  Q_EMIT jttySessionDrained(drain.epoch.value ());
}

void MainWindow::onJttyBackendEnqueueAccepted(qint64 enqueueId, qint64 sampleCount,
                                              TxAudioQueueProgress progress)
{
  if (m_mode != "JTTY" || !m_jttyTxActive
      || progress.epoch != m_jttyTxQueueEpoch) {
    return;
  }

  for (int i = 0; i < m_pendingJttyTciMessages.size (); ++i) {
    auto const pending = m_pendingJttyTciMessages.at (i);
    if (pending.epoch != progress.epoch || pending.enqueueId != enqueueId) {
      continue;
    }

    m_pendingJttyTciMessages.remove (i);
    if (sampleCount != pending.sampleCount) {
      LOG_WARN("JTTY transmit backend accepted unexpected PCM sample count");
    }
    bool const startsSession = pending.newSession
      || m_jttyTxQueueProgress.total_samples <= 0;
    completeJttyTxEnqueue(pending.requestId, pending.message, progress,
                          startsSession, true);
    return;
  }
}

void MainWindow::onJttyBackendEnqueueFailed(TxAudioQueueEpoch epoch,
                                            qint64 enqueueId)
{
  if (m_mode != "JTTY" || !m_jttyTxActive
      || epoch != m_jttyTxQueueEpoch) {
    return;
  }

  LOG_WARN("JTTY transmit backend rejected PCM enqueue");
  for (int i = 0; i < m_pendingJttyTciMessages.size (); ++i) {
    auto const pending = m_pendingJttyTciMessages.at (i);
    if (pending.epoch != epoch || pending.enqueueId != enqueueId) {
      continue;
    }
    m_pendingJttyTciMessages.remove (i);
    Q_EMIT jttyTextRejected(pending.requestId, JttyTxRejectReason::QueueFull);
    if (pending.newSession && m_jttyTxQueueProgress.total_samples <= 0) {
      for (int j = 0; j < m_pendingJttyTciMessages.size (); ++j) {
        if (m_pendingJttyTciMessages[j].epoch == epoch) {
          m_pendingJttyTciMessages[j].newSession = true;
          return;
        }
      }
      resetJttyTxState();
    }
    return;
  }
}

void MainWindow::rejectPendingJttyTciMessages(JttyTxRejectReason reason)
{
  for (auto const& pending : m_pendingJttyTciMessages) {
    Q_EMIT jttyTextRejected(pending.requestId, reason);
  }
}

void MainWindow::handleJttyTxWatchdog()
{
  if (m_mode != "JTTY" || !m_jttyTxActive) {
    return;
  }

  LOG_WARN("JTTY transmit completion watchdog expired");
  noteTxStopReason (TxEvidence::TxStopReason::Watchdog);
  interruptJttyTx();
#ifdef WIN32
  if (m_mmttyif) {
    m_mmttyif->report_ptt_state(false);
  }
#endif
  stopTx();
}

void MainWindow::resetJttyTxState()
{
  m_jttyTxWatchdog.stop();
  m_jttyTxActive = false;
  m_jttyTxQueueProgress = {};
  m_jttyTxQueueProgress.epoch = m_jttyTxQueueEpoch;
  m_pendingJttyTciMessages.clear();
  m_acceptedJttyTxRequests.clear();
}

void MainWindow::startJttyTxWatchdog(int durationMs)
{
  if (durationMs > 0) {
    m_jttyTxWatchdog.start(durationMs);
  }
}

void MainWindow::jtty_again()
{
  startJttyReview(0, 0, false);
}

void MainWindow::jttyDecodeAgainAtSample(quint64 reception, qint64 sample)
{
  startJttyReview(reception, sample, true);
}

bool MainWindow::jtty_key_struck(QKeyEvent * e)
{
  if(e->key() == Qt::Key_Escape) {
    abort_jtty_tx();
    return true;
  }
  int const functionKey=e->key()-Qt::Key_F1+1;
  if(functionKey < 1 || functionKey > 8) return false;
  return sendJttyFunctionKey(functionKey);
}

bool MainWindow::sendJttyFunctionKey(int index)
{
  QString macro;
  switch(index) {
  case 1: macro=ui->msg1->text(); break;
  case 2: macro=ui->msg2->text(); break;
  case 3: macro=ui->msg3->text(); break;
  case 4: macro=ui->msg4->text(); break;
  case 5: macro=ui->msg5->text(); break;
  case 6: macro=ui->msg6->text(); break;
  case 7: macro=ui->msg7->text(); break;
  case 8: macro=ui->msg8->text(); break;
  default: return false;
  }
  if(macro.simplified().isEmpty()) return false;

  auto const context = jttyNativeMacroContext(
    m_config, m_hisCall, ui->sbSerialNumber_2->value(), m_jttyHisCallSnr);
  auto const compiled=Jtty::compileNativeMacro(macro,context);
  if(compiled.status == Jtty::NativeMacroStatus::LiteralFallback) {
    jtty_tx(compiled.text);
    return true;
  }

  qint64 const requestId=++m_jttyTxRequestId;
  if(compiled.status == Jtty::NativeMacroStatus::InvalidRuntime) {
    LOG_WARN(QStringLiteral("JTTY native macro rejected: %1").arg(compiled.error));
    Q_EMIT jttyTextRejected(requestId,JttyTxRejectReason::EncodingFailed);
    return true;
  }

  int itone[944];
  int nsym=0;
  int encodeStatus=static_cast<int>(Jtty::NativeEncodeStatus::InvalidDescriptor);
  genjtty_atoms_c(compiled.atoms.constData(),compiled.atoms.size(),itone,&nsym,
                  &encodeStatus);
  if(nsym <= 0) {
    LOG_WARN(QStringLiteral("JTTY native macro rejected: %1")
             .arg(jttyNativeEncodeError(encodeStatus)));
    Q_EMIT jttyTextRejected(requestId,JttyTxRejectReason::EncodingFailed);
    return true;
  }
  execute_jtty_tones(requestId,compiled.text,itone,nsym);
  return true;
}

QString MainWindow::jtty_msg_expand(QString t)
{
  auto const context = jttyNativeMacroContext(
    m_config, m_hisCall, ui->sbSerialNumber_2->value(), m_jttyHisCallSnr);
  return Jtty::expandLiteralMacro(t, context);
}

void MainWindow::on_RxFreqSpinBox_2_valueChanged(int n)
{
    ui->RxFreqSpinBox->setValue(n);
}

void MainWindow::on_TxFreqSpinBox_2_valueChanged(int n)
{
    ui->TxFreqSpinBox->setValue(n);
}

void MainWindow::on_sbFtol_2_valueChanged (int n)
{
  m_wideGraph->setTol(n);
}

void MainWindow::on_comboBoxJttyStyle_currentIndexChanged(int index)
{
  auto const previousStyle = static_cast<Jtty::MessageStyle>(m_jttyMessageStyle);
  auto const newStyle = static_cast<Jtty::MessageStyle>(index);
  QLineEdit* const msgFields[8] = {ui->msg1, ui->msg2, ui->msg3, ui->msg4,
                                    ui->msg5, ui->msg6, ui->msg7, ui->msg8};

  m_settings->beginGroup("MainWindow");
  for (int i = 0; i < 8; ++i) {
    // Save the outgoing style's currently displayed text before switching away,
    // so in-session edits aren't lost.
    m_settings->setValue(Jtty::messageStyleSettingsKey(previousStyle, i + 1),
                          msgFields[i]->text());
  }
  for (int i = 0; i < 8; ++i) {
    int const functionKey = i + 1;
    msgFields[i]->setText(m_settings->value(
      Jtty::messageStyleSettingsKey(newStyle, functionKey),
      Jtty::messageStyleDefaultTemplate(newStyle, functionKey)).toString());
  }
  m_settings->endGroup();
  m_jttyMessageStyle = index;
}

#ifdef WIN32
void MainWindow::logText(const QString &text) {
  LOG_INFO(text);
}

QString MainWindow::jttyRejectReasonText(JttyTxRejectReason reason) const
{
  switch (reason) {
  case JttyTxRejectReason::Empty: return QStringLiteral("empty");
  case JttyTxRejectReason::EncodingFailed: return QStringLiteral("encoding failed");
  case JttyTxRejectReason::QueueFull: return QStringLiteral("queue full");
  case JttyTxRejectReason::BackendRejected: return QStringLiteral("backend rejected");
  case JttyTxRejectReason::Aborted: return QStringLiteral("aborted");
  case JttyTxRejectReason::NotAvailable: return QStringLiteral("not available");
  }
  return QStringLiteral("unknown");
}

void MainWindow::handleMmttyTxString(QString message)
{
  auto const context = jttyNativeMacroContext(
    m_config, m_hisCall, ui->sbSerialNumber_2->value(), m_jttyHisCallSnr);
  auto const compiled = Jtty::compileN1mmMessage(message, context);
  if (m_mode != "JTTY") {
    if (compiled.status == Jtty::N1mmCompileStatus::Literal) {
      jtty_tx(compiled.literalText);
      return;
    }

    qint64 const requestId = ++m_jttyTxRequestId;
    m_mmttyJttyOutput.submit(requestId);
    QString const reason = compiled.status == Jtty::N1mmCompileStatus::Error
      ? compiled.error : QStringLiteral("tagged JTTY actions require JTTY mode");
    logText(QStringLiteral("MMTTY/N1MM tagged JTTY request %1 rejected: %2")
            .arg(requestId).arg(reason));
    Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::NotAvailable);
    return;
  }

  if (m_mmttyJttyOutput.finishRequested()) {
    logText(QStringLiteral("MMTTY/N1MM JTTY text ignored after graceful OFF"));
    return;
  }

  qint64 const requestId = ++m_jttyTxRequestId;
  m_mmttyJttyOutput.submit(requestId);
  if (compiled.status == Jtty::N1mmCompileStatus::Literal) {
    execute_jtty_tx(requestId, compiled.literalText);
    return;
  }
  if (compiled.status == Jtty::N1mmCompileStatus::Error) {
    logText(QStringLiteral("MMTTY/N1MM tagged JTTY request %1 rejected: %2")
            .arg(requestId).arg(compiled.error));
    Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::EncodingFailed);
    return;
  }

  int itone[944];
  int nsym = 0;
  int encodeStatus = static_cast<int>(Jtty::NativeEncodeStatus::InvalidDescriptor);
  genjtty_atoms_c(compiled.atoms.constData(), compiled.atoms.size(), itone, &nsym,
                  &encodeStatus);
  if (nsym <= 0) {
    logText(QStringLiteral("MMTTY/N1MM tagged JTTY request %1 rejected: %2")
            .arg(requestId).arg(jttyNativeEncodeError(encodeStatus)));
    Q_EMIT jttyTextRejected(requestId, JttyTxRejectReason::EncodingFailed);
    return;
  }
  execute_jtty_tones(requestId, compiled.canonicalText, itone, nsym);
}

void MainWindow::handleMmttyStartTx()
{
  if (m_mode != "JTTY" && !m_mmttyJttyOutput.pending()) {
    startTx2();
    return;
  }

  m_mmttyJttyOutput.start();
  startPendingMmttyJttyTx();
}

void MainWindow::handleMmttyStopTx()
{
  if (m_mode != "JTTY") {
    noteTxStopReason (TxEvidence::TxStopReason::UserHalt);
    stopTx();
    if (!m_mmttyJttyOutput.pending()) return;
  }

  m_mmttyJttyOutput.finish();
  logText(QStringLiteral("MMTTY/N1MM JTTY OFF requested; waiting for backend drain"));
  completeMmttyJttyOutput();
}

void MainWindow::handleMmttyAbortTx()
{
  m_mmttyJttyOutput.abort();
  abort_jtty_tx();
}

void MainWindow::handleMmttyJttyAccepted(qint64 requestId)
{
  if (!m_mmttyJttyOutput.accept(requestId)) return;

  logText(QStringLiteral("MMTTY/N1MM JTTY request %1 accepted").arg(requestId));
  startPendingMmttyJttyTx();
}

void MainWindow::handleMmttyJttyRejected(qint64 requestId, JttyTxRejectReason reason)
{
  if (!m_mmttyJttyOutput.resolve(requestId)) return;

  logText(QStringLiteral("MMTTY/N1MM JTTY request %1 rejected: %2")
          .arg(requestId)
          .arg(jttyRejectReasonText(reason)));
  // Backend rejection may reset the audio session after emitting this signal.
  QTimer::singleShot(0, this, [this] { completeMmttyJttyOutput(); });
}

void MainWindow::handleMmttyJttyCompleted(qint64 requestId)
{
  if (!m_mmttyJttyOutput.resolve(requestId)) return;

  logText(QStringLiteral("MMTTY/N1MM JTTY request %1 completed").arg(requestId));
}

void MainWindow::handleMmttyJttySessionDrained(qint64 sessionId)
{
  Q_UNUSED(sessionId)
  completeMmttyJttyOutput(true);
}

void MainWindow::completeMmttyJttyOutput(bool drained)
{
  if (m_mmttyJttyOutput.takeCompletion(m_jttyTxActive, drained) && m_mmttyif) {
    m_mmttyif->report_output_complete();
  }
}

void MainWindow::startPendingMmttyJttyTx()
{
  if (m_mode != "JTTY" || !m_mmttyJttyOutput.startRequested()) return;

  if (!m_jttyTxActive || jttyTxCommittedSamples () <= 0) {
    logText(QStringLiteral("MMTTY/N1MM JTTY start deferred until text is accepted"));
    return;
  }

  if (g_iptt == 1) {
    logText(QStringLiteral("MMTTY/N1MM JTTY start ignored; transmitter is already keyed"));
    m_mmttyJttyOutput.started();
    return;
  }

  m_mmttyJttyOutput.started();
  startTx2();
}

void MainWindow::initMMTTY(quint16 port) {
    if (!m_mmttyif) {
        m_mmttyif = new MMTTYIF(this);
    }

    m_mmttyif->initialize(port);

    connect(m_mmttyif, &MMTTYIF::log_message, this, &MainWindow::logText);
    connect(m_mmttyif, &MMTTYIF::app_tx_string, this, &MainWindow::handleMmttyTxString);
    connect(m_mmttyif, &MMTTYIF::app_start_tx, this, &MainWindow::handleMmttyStartTx);
    connect(m_mmttyif, &MMTTYIF::app_stop_tx, this, &MainWindow::handleMmttyStopTx);
    connect(m_mmttyif, &MMTTYIF::app_abort_tx, this, &MainWindow::handleMmttyAbortTx);
    connect(this, &MainWindow::jttyTextAccepted, this, &MainWindow::handleMmttyJttyAccepted);
    connect(this, &MainWindow::jttyTextRejected, this, &MainWindow::handleMmttyJttyRejected);
    connect(this, &MainWindow::jttyTextCompleted, this, &MainWindow::handleMmttyJttyCompleted);
    connect(this, &MainWindow::jttySessionDrained, this, &MainWindow::handleMmttyJttySessionDrained);

    connect(m_mmttyif, &MMTTYIF::inactivity_timeout, qApp, &QCoreApplication::quit);
    connect(m_mmttyif, &MMTTYIF::app_is_quitting, this, [this]() {
        abort_jtty_tx();
        close();
    });

    // Auto-switch to JTTY mode after MMTTY connects
    QTimer::singleShot(3000, this, [this]() {
         set_mode("JTTY");
    });
}

MMTTYIF *MainWindow::getMmttyIf() const {
    return m_mmttyif;
}
#endif
