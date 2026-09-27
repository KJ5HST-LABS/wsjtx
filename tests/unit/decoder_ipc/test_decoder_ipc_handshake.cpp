#include <QtTest>
#include <QProcess>
#include <QSharedMemory>
#include <QTemporaryDir>
#include <QUuid>

#include <cstddef>
#include <cstring>
#include <memory>

#include "DecoderIpc.hpp"

namespace
{
  class DecoderProcess : public QProcess
  {
  public:
    ~DecoderProcess () override
    {
      if (state () != NotRunning)
        {
          kill ();
          waitForFinished (5000);
        }
    }
    void launch (QString const& key, QString const& directory)
    {
      start (QStringLiteral (DECODER_IPC_JT9),
             {"-s", key, "-w", "1", "-m", "1", "-e", directory,
              "-a", directory, "-t", directory, "-r", QStringLiteral (DECODER_IPC_SOURCE)});
    }
  };

  QString uniqueKey ()
  {
    return QString {"decoder-handshake-%1"}.arg (QUuid::createUuid ().toString ());
  }
}

class TestDecoderIpcHandshake final : public QObject
{
  Q_OBJECT
private Q_SLOTS:
  void readyBeforePublication ();
  void rejectsSegment_data ();
  void rejectsSegment ();
  void ownerRejectsIncompatibleAttachment ();
};

void TestDecoderIpcHandshake::readyBeforePublication ()
{
  using namespace DecoderIpc;
  auto const key = uniqueKey ();
  QTemporaryDir directory;
  QVERIFY (directory.isValid ());
  Session session;
  QCOMPARE (session.open (key), Status::Ok);
  auto source = std::make_unique<dec_data_t> ();
  QCOMPARE (session.submit (Request::snapshot (*source)).status, Status::Unavailable);
  DecoderProcess child;
  child.launch (key, directory.path ());
  QVERIFY (child.waitForStarted (5000));
  QByteArray output;
  QElapsedTimer timer;
  timer.start ();
  while (!output.contains ('\n') && timer.elapsed () < 5000)
    {
      child.waitForReadyRead (100);
      output += child.readAllStandardOutput ();
      if (child.state () == QProcess::NotRunning) break;
    }
  QVERIFY2 (output.startsWith ("<DecoderReady> version=3\r\n")
            || output.startsWith ("<DecoderReady> version=3\n"), output.constData ());
  QVERIFY (!output.contains ("<DecodeStarted>"));
  QCOMPARE (session.acceptReady (DECODER_IPC_VERSION), Status::Ok);
  QVERIFY (session.ready ());
  session.shutdown ();
  QVERIFY (child.waitForFinished (5000));
  output += child.readAllStandardOutput ();
  QCOMPARE (child.exitStatus (), QProcess::NormalExit);
  QCOMPARE (child.exitCode (), 0);
  QVERIFY2 (!output.contains ("<DecoderError>"), output.constData ());
}

void TestDecoderIpcHandshake::rejectsSegment_data ()
{
  QTest::addColumn<QString> ("mutation");
  QTest::addColumn<QByteArray> ("status");
  QTest::newRow ("v1") << QString {"v1"} << QByteArray {"unsupported-version"};
  QTest::newRow ("v2") << QString {"v2"} << QByteArray {"unsupported-version"};
  QTest::newRow ("future-version") << QString {"v4"} << QByteArray {"unsupported-version"};
  QTest::newRow ("header-size") << QString {"header"} << QByteArray {"wrong-header-size"};
  QTest::newRow ("payload-size") << QString {"payload"} << QByteArray {"wrong-payload-size"};
  QTest::newRow ("field-offset") << QString {"offset"} << QByteArray {"incompatible-layout"};
  QTest::newRow ("capabilities") << QString {"caps"} << QByteArray {"unsupported-capabilities"};
  QTest::newRow ("truncated") << QString {"truncated"} << QByteArray {"truncated-segment"};
}

void TestDecoderIpcHandshake::rejectsSegment ()
{
  QFETCH (QString, mutation);
  QFETCH (QByteArray, status);
  auto const key = uniqueKey ();
  QTemporaryDir directory;
  QVERIFY (directory.isValid ());
  QSharedMemory memory {key};
  bool const truncated = mutation == "truncated";
  QVERIFY2 (memory.create (truncated ? offsetof (shared_dec_data_t, payload)
                                    : sizeof (shared_dec_data_t)),
            qPrintable (memory.errorString ()));
  if (truncated)
    {
      auto * control = static_cast<decoder_ipc_control_t *> (memory.data ());
      *control = {1, DECODER_IPC_READY, DECODER_IPC_VERSION, 0};
      decoder_ipc_layout_t layout;
      decoder_ipc_expected_layout (&layout);
      std::memcpy (static_cast<unsigned char *> (memory.data ())
                   + offsetof (shared_dec_data_t, layout),
                   &layout, sizeof layout);
    }
  else
    {
      auto& shared = *static_cast<shared_dec_data_t *> (memory.data ());
      DecoderIpc::initialize (shared);
      shared.control.state = DECODER_IPC_READY;
      shared.control.generation = 1;
      if (mutation.startsWith ('v')) shared.control.version = mutation.mid (1).toInt ();
      if (mutation == "header") ++shared.layout.header_bytes;
      if (mutation == "payload") --shared.layout.payload_bytes;
      if (mutation == "offset") ++shared.layout.fields[7].offset;
      if (mutation == "caps") shared.layout.capabilities = 0;
    }
  QByteArray const before {static_cast<char const *> (memory.constData ()), memory.size ()};
  DecoderProcess child;
  child.launch (key, directory.path ());
  QVERIFY (child.waitForStarted (5000));
  QVERIFY (child.waitForFinished (5000));
  auto const output = child.readAllStandardOutput ();
  QCOMPARE (child.exitStatus (), QProcess::NormalExit);
  QCOMPARE (child.exitCode (), 1);
  QVERIFY2 (output.contains ("<DecoderError> status=" + status), output.constData ());
  QVERIFY (!output.contains ("<DecoderReady>"));
  QVERIFY (!output.contains ("<DecodeStarted>"));
  QCOMPARE (std::memcmp (before.constData (), memory.constData (), before.size ()), 0);
}

void TestDecoderIpcHandshake::ownerRejectsIncompatibleAttachment ()
{
  auto const key = uniqueKey ();
  QSharedMemory memory {key};
  QVERIFY (memory.create (sizeof (shared_dec_data_t)));
  auto& shared = *static_cast<shared_dec_data_t *> (memory.data ());
  DecoderIpc::initialize (shared);
  shared.control.version = 2;
  QByteArray const before {static_cast<char const *> (memory.constData ()), memory.size ()};
  DecoderIpc::Session session;
  QCOMPARE (session.open (key), DecoderIpc::Status::Incompatible);
  QVERIFY (session.errorString ().contains ("unsupported-version"));
  QCOMPARE (std::memcmp (before.constData (), memory.constData (), before.size ()), 0);
}

QTEST_GUILESS_MAIN (TestDecoderIpcHandshake)
#include "test_decoder_ipc_handshake.moc"
