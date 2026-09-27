#include <QtTest>
#include <QSharedMemory>
#include <QUuid>

#include <memory>

#include "DecoderIpc.hpp"

class TestDecoderSession final : public QObject
{
  Q_OBJECT
private Q_SLOTS:
  void ownsGenerationsAndSamples ();
  void compactSnapshotAndContextRefresh ();
};

void TestDecoderSession::ownsGenerationsAndSamples ()
{
  using namespace DecoderIpc;
  Session session;
  auto const key = QString {"decoder-session-%1"}.arg (QUuid::createUuid ().toString ());
  QCOMPARE (session.open (key), Status::Ok);
  QSharedMemory peer {key};
  QVERIFY (peer.attach ());
  auto& shared = *static_cast<shared_dec_data_t *> (peer.data ());
  auto source = std::make_unique<dec_data_t> ();
  source->params.nmode = 8;
  source->params.ntrperiod = 15;
  source->params.kin = 150000;
  source->params.newdat = true;
  source->d2[0] = 17;
  source->d2[60 * RX_SAMPLE_RATE - 1] = 29;

  QCOMPARE (session.submit (Request::reuse (*source, {})).status, Status::StaleSamples);
  auto first = session.submit (Request::snapshot (*source));
  QVERIFY (first);
  QVERIFY (first.samples);
  QVERIFY (!session.samples ());
  QCOMPARE (first.generation.value (), 1);
  QCOMPARE (shared.payload.d2[0], short {17});
  QCOMPARE (shared.payload.d2[60 * RX_SAMPLE_RATE - 1], short {29});
  QCOMPARE (session.submit (Request::snapshot (*source)).status, Status::Busy);
  QVERIFY (!session.accepts (0));
  QVERIFY (session.accepts (1));
  QCOMPARE (session.complete ({0, 0, 0, 2}), Status::StaleGeneration);
  qint32 generation {0};
  QVERIFY (claim (shared, generation));
  QVERIFY (finish (shared, generation));
  QCOMPARE (session.complete ({0, 0, 0, generation}), Status::Ok);
  QVERIFY (session.samples ());
  QCOMPARE (session.complete ({0, 0, 0, generation}), Status::StaleGeneration);

  source->d2[0] = 99;
  source->params.newdat = false;
  source->params.nfqso = 1234;
  auto const samples = session.samples ();
  auto second = session.submit (Request::reuse (*source, samples));
  QVERIFY (second);
  QCOMPARE (second.generation.value (), 2);
  QCOMPARE (shared.payload.d2[0], short {17});
  QCOMPARE (shared.payload.params.nfqso, 1234);
  QCOMPARE (session.complete ({0, 0, 0, 1}), Status::StaleGeneration);
  QCOMPARE (shared.control.generation, 2);

  session.abort ();
  QVERIFY (!session.samples ());
  QVERIFY (!session.accepts (2));
  session.shutdown ();
  QVERIFY (session.reset ());
  QCOMPARE (session.submit (Request::reuse (*source, samples)).status, Status::StaleSamples);
  auto third = session.submit (Request::snapshot (*source));
  QVERIFY (third);
  QCOMPARE (third.generation.value (), 3);
  QCOMPARE (shared.payload.d2[0], short {99});
  session.shutdown ();
}

void TestDecoderSession::compactSnapshotAndContextRefresh ()
{
  using namespace DecoderIpc;
  Session session;
  auto const key = QString {"decoder-session-%1"}.arg (QUuid::createUuid ().toString ());
  QCOMPARE (session.open (key), Status::Ok);
  QSharedMemory peer {key};
  QVERIFY (peer.attach ());
  auto& shared = *static_cast<shared_dec_data_t *> (peer.data ());
  auto compact = std::make_unique<Ft8MtdPayload> ();
  compact->params.nmode = 8;
  compact->params.ntrperiod = 15;
  compact->params.kin = 150000;
  compact->params.lmultift8 = true;
  compact->samples.front () = 31;
  compact->samples.back () = 47;
  shared.payload.ss[0] = 5.5F;
  auto first = session.submit (Request::ft8 (*compact));
  QVERIFY (first);
  QCOMPARE (shared.payload.d2[0], short {31});
  QCOMPARE (shared.payload.d2[Ft8SampleCount - 1], short {47});
  QCOMPARE (shared.payload.ss[0], 5.5F);
  qint32 generation {0};
  QVERIFY (claim (shared, generation));
  QVERIFY (finish (shared, generation));
  QCOMPARE (session.complete ({0, 0, 0, generation}), Status::Ok);

  auto source = std::make_unique<dec_data_t> ();
  source->params.nmode = 65;
  source->params.ntrperiod = 60;
  source->params.kin = 60 * RX_SAMPLE_RATE;
  source->params.nagain = true;
  source->d2[0] = 73;
  QVERIFY (session.submit (Request::reuse (*source, session.samples ())));
  QCOMPARE (shared.payload.d2[0], short {73});
  QVERIFY (shared.payload.params.newdat);
  QVERIFY (!shared.payload.params.nagain);
  session.shutdown ();
}

QTEST_GUILESS_MAIN (TestDecoderSession)
#include "test_decoder_session.moc"
