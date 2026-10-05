#include "JttyReceiveResultController.hpp"
#include "JttyReceiveTiming.hpp"

#include <QRegularExpression>

namespace Jtty {

void ReceiveResultController::apply(QVector<ReceiveUpdate> const& updates,
                                    Reception const& reception,
                                    Inputs const& inputs, Effects const& effects)
{
  auto& lines = reception.source == Source::Live ? liveLines_ : replayLines_;
  for (auto const& update : updates) {
    if (update.text.isEmpty()) continue;
    if (reception.source == Source::Review && !reviewHeading_) {
      effects.reviewHeading(Pane::All);
      effects.reviewHeading(Pane::Qso);
      reviewHeading_ = true;
    }
    bool const known = lines.contains(update.messageId);
    auto& line = lines[update.messageId];
    if (!known) {
      line.context = reception.context;
      line.context.sequenceStart = reception.anchor.addMSecs(qRound64(update.startSeconds * 1000.0));
    }
    auto const change = compareMessages(line.text, update.text);
    JttyReceiveLine::Presentation const presentation {reception.displayGroup, update.messageId,
      reception.displayAnchor.addMSecs(qRound64(update.startSeconds * 1000.0)), update.startSeconds,
      qRound(update.frequency), update.text, update.snr};
    auto const options = inputs.display();
    effects.render(Pane::All, line.allLine, presentation, options);
    auto const selection = inputs.selection();
    bool const current = reception.source == Source::Live && selection.jttyActive
      && reception.contextId == selection.contextId;
    float const center = current ? selection.center : reception.center;
    float const tolerance = current ? selection.tolerance : reception.tolerance;
    bool const wasAdmitted = line.admitted;
    line.admitted = shouldApplyToQsoHistory(line.admitted, update.frequency, center, tolerance);
    if (line.admitted) {
      effects.render(Pane::Qso, line.qsoLine, presentation, options);
      if (reception.source != Source::Review) {
        auto const echo = inputs.echo();
        if (echo.enabled && (change.messageChanged || !wasAdmitted)) {
          QString delta = wasAdmitted && change.extendsMessage ? change.appendedText : update.text;
          if (!wasAdmitted || !change.extendsMessage) delta.prepend("\r\n");
          if (echo.lowerCase) delta = delta.toLower();
          effects.echo(delta);
        }
      }
    }
    line.text = update.text;
    if (reception.source == Source::Live) {
      auto const start = qRound64(update.latestSeconds * 12000.0);
      effects.noteDecoded(start, start + receiveFrameSamples);
    }
    if (reception.source != Source::Review && update.terminal != ReceiveTerminal::Growing) {
      effects.log(formatJttyDecodeLine(qRound(update.frequency), update.snr, update.text), line.context);
      if (reception.source == Source::Live && update.terminal == ReceiveTerminal::Complete
          && inputs.reporting()) {
        auto const fields = update.text.simplified().split(QChar{' '}, Qt::SkipEmptyParts);
        if (fields.size() >= 2) {
          auto const& first = fields.at(0);
          auto const& sender = fields.at(1);
          bool const structured = (first.compare(QStringLiteral("CQ"), Qt::CaseInsensitive) == 0
                                   || first.compare(QStringLiteral("DE"), Qt::CaseInsensitive) == 0
                                   || Radio::is_standard_callsign(first))
                                  && Radio::is_standard_callsign(sender);
          bool const selfSpot = sender.compare(line.context.myCall, Qt::CaseInsensitive) == 0;
          if (structured && !selfSpot) {
            QString grid;
            if (fields.size() >= 3 && fields.at(2).contains(Radio::decoded_grid_pattern()))
              grid = fields.at(2);
            auto const frequency = line.context.periodFrequency + qRound(update.frequency);
            auto const spotTime = line.context.sequenceStart.toUTC();
            if (spotTime.isValid())
              effects.spot({sender, grid, frequency, QStringLiteral("JTTY"), update.snr, spotTime});
          }
        }
      }
    }
    snrHistory_.push_back({update.text, update.snr, line.admitted});
    if (snrHistory_.size() > 500) snrHistory_.pop_front();
    if (update.terminal != ReceiveTerminal::Growing) lines.remove(update.messageId);
  }
}

void ReceiveResultController::resetReplay()
{
  reviewHeading_ = false;
  replayLines_.clear();
}

int ReceiveResultController::snrForSelectedWord(QString const& word, Pane pane) const
{
  for (auto it = snrHistory_.crbegin(); it != snrHistory_.crend(); ++it) {
    if (pane == Pane::Qso && !it->admitted) continue;
    if (it->text.split(QChar{' '}, Qt::SkipEmptyParts).contains(word)) return it->snr;
  }
  return -10;
}

}
