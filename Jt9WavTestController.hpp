#ifndef JT9_WAV_TEST_CONTROLLER_HPP__
#define JT9_WAV_TEST_CONTROLLER_HPP__

#include <QObject>
#include <QString>
#include <QTimer>

class MainWindow;

class Jt9WavTestController final : public QObject
{
public:
  Jt9WavTestController (MainWindow * window, QString wavPath,
                        QString expectedMessage, QObject * parent = nullptr);
  void begin ();
  bool succeeded () const {return m_succeeded;}

private:
  void prepareWhenReady ();
  void completeCycle (quint64 generation);
  void finish (QString const& error = {});

  MainWindow * m_window;
  QString m_wavPath;
  QString m_expectedMessage;
  QTimer m_timeout;
  QTimer m_prepareTimer;
  QTimer m_modalTimer;
  quint64 m_activeGeneration {0};
  quint64 m_lastGeneration {0};
  int m_completedCycles {0};
  bool m_awaitingCycle {false};
  bool m_observed {false};
  bool m_configured {false};
  bool m_started {false};
  bool m_finished {false};
  bool m_succeeded {false};
};

#endif
