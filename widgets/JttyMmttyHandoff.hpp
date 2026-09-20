// -*- Mode: C++ -*-
#ifndef JTTY_MMTTY_HANDOFF_HPP
#define JTTY_MMTTY_HANDOFF_HPP

#include <QVector>
#include <QtGlobal>

namespace Jtty
{
  class MmttyHandoff
  {
  public:
    enum class SubmitAction
    {
      Reject,
      Submit,
      StopThenSubmit
    };

    bool active () const noexcept {return waitingForStop_;}
    bool empty () const noexcept {return requestIds_.isEmpty ();}
    QVector<qint64> const& requestIds () const noexcept {return requestIds_;}

    static SubmitAction planSubmission (bool valid, bool jttySessionActive,
                                        bool backendBusy) noexcept
    {
      if (!valid) return SubmitAction::Reject;
      if (!jttySessionActive && backendBusy) {
        return SubmitAction::StopThenSubmit;
      }
      return SubmitAction::Submit;
    }

    bool queue (qint64 requestId)
    {
      if (requestIds_.size () >= 64) return false;
      requestIds_.append (requestId);
      return true;
    }
    void waitForStop () noexcept {waitingForStop_ = true;}

    bool stopCompleted () noexcept
    {
      if (!waitingForStop_) return false;
      waitingForStop_ = false;
      return true;
    }

    void submitted (qint64 requestId) {requestIds_.removeOne (requestId);}
    void abort () {reset ();}

  private:
    void reset ()
    {
      requestIds_.clear ();
      waitingForStop_ = false;
    }

    QVector<qint64> requestIds_;
    bool waitingForStop_ {false};
  };
}

#endif
