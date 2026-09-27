#include "DecoderIpc.hpp"

#include "lib/decoder_ipc_control.h"
#include <QThread>

#include <algorithm>
#include <cstring>
#include <limits>

namespace
{
  int sampleCountToCopy (int period)
  {
    switch (period)
      {
      case 7: // FT4's 7.5-second period is stored as an integer.
      case 15:
      case 30:
      case 60:
      case 120:
      case 300:
      case 900:
      case 1800:
        // Legacy decoders read fixed windows beyond the received sample count.
        return std::min (NTMAX, std::max (60, period)) * RX_SAMPLE_RATE;
      default:
        return NTMAX * RX_SAMPLE_RATE;
      }
  }

  bool hasCurrentProtocol (shared_dec_data_t const& shared)
  {
    return DECODER_IPC_LAYOUT_OK == decoder_ipc_validate_layout (
        &shared, sizeof shared, nullptr);
  }

  bool parseField (QByteArray const& field, qint32& value)
  {
    bool ok {false};
    auto const parsed = field.toInt (&ok);
    if (!ok) return false;
    value = parsed;
    return true;
  }

  bool parseGeneration (QByteArray const& text, qint32& generation)
  {
    if (text.isEmpty ()) return false;
    for (auto const digit: text)
      {
        if (digit < '0' || digit > '9') return false;
      }
    return parseField (text, generation) && generation > 0;
  }
}

DecoderIpc::Request::Request (Kind kind, dec_data_t const * source,
                              Ft8MtdPayload const * compact, SampleIdentity samples)
  : kind_ {kind}, source_ {source}, compact_ {compact}, samples_ {samples}
{
}

DecoderIpc::Request DecoderIpc::Request::snapshot (dec_data_t const& source)
{
  return {Kind::Snapshot, &source, nullptr};
}

DecoderIpc::Request DecoderIpc::Request::reuse (dec_data_t const& source,
                                             SampleIdentity samples)
{
  return {Kind::Reuse, &source, nullptr, samples};
}

DecoderIpc::Request DecoderIpc::Request::ft8 (Ft8MtdPayload const& source)
{
  return {Kind::Ft8, nullptr, &source};
}

decoder_params_t const& DecoderIpc::Request::options () const
{
  return compact_ ? compact_->params : source_->params;
}

DecoderIpc::Status DecoderIpc::Session::open (QString const& key)
{
  detach ();
  error_.clear ();
  memory_.setKey (key);
  for (int attempt = 0; attempt < 3; ++attempt)
    {
      if (!memory_.attach ()) break;
      auto const status = decoder_ipc_validate_layout (
          memory_.constData (), memory_.size (), nullptr);
      if (DECODER_IPC_LAYOUT_OK != status)
        {
          error_ = QStringLiteral ("Decoder shared memory rejected: %1 (expected version %2, header %3, payload %4 bytes)")
            .arg (decoder_ipc_layout_status_name (status)).arg (DECODER_IPC_VERSION)
            .arg (offsetof (shared_dec_data_t, payload)).arg (sizeof (dec_data_t));
          memory_.detach ();
          return Status::Incompatible;
        }
      DecoderIpc::shutdown (*static_cast<shared_dec_data_t *> (memory_.data ()));
      memory_.detach ();
      QThread::sleep (1);
    }
  if (memory_.attach ())
    {
      error_ = QStringLiteral ("Orphaned decoder shared memory remained after shutdown attempts");
      memory_.detach ();
      return Status::Orphaned;
    }
  if (!memory_.create (sizeof (shared_dec_data_t)))
    {
      error_ = memory_.errorString ();
      return Status::CreateFailed;
    }
  initialize (*static_cast<shared_dec_data_t *> (memory_.data ()));
  return Status::Ok;
}

shared_dec_data_t const * DecoderIpc::Session::storage () const
{
  if (!hasUsableSize (memory_.size ()) || !memory_.constData ()) return nullptr;
  auto const * shared = static_cast<shared_dec_data_t const *> (memory_.constData ());
  return hasCurrentProtocol (*shared) ? shared : nullptr;
}

shared_dec_data_t * DecoderIpc::Session::storage ()
{
  return const_cast<shared_dec_data_t *> (static_cast<Session const *> (this)->storage ());
}

bool DecoderIpc::Session::reset ()
{
  auto * shared = storage ();
  if (!shared) return false;
  beginStartup ();
  initialize (*shared);
  return true;
}

void DecoderIpc::Session::beginStartup ()
{
  ready_ = false;
  abort ();
}

DecoderIpc::Status DecoderIpc::Session::acceptReady (int version)
{
  auto const * shared = storage ();
  if (ready_ || version != DECODER_IPC_VERSION || !shared
      || state (*shared) != DECODER_IPC_IDLE || generation (*shared) != 0)
    {
      ready_ = false;
      error_ = QStringLiteral ("Invalid or incompatible decoder startup handshake");
      return Status::Incompatible;
    }
  ready_ = true;
  return Status::Ok;
}

void DecoderIpc::Session::shutdown ()
{
  ready_ = false;
  if (auto * shared = storage ()) DecoderIpc::shutdown (*shared);
}

void DecoderIpc::Session::detach ()
{
  beginStartup ();
  if (memory_.isAttached ()) memory_.detach ();
}

DecoderIpc::Submission DecoderIpc::Session::submit (Request const& request)
{
  if (!ready_) return {Status::Unavailable, {}, {}};
  auto * shared = storage ();
  if (!shared) return {Status::Incompatible, {}, {}};
  if (activeGeneration_.value () || DECODER_IPC_IDLE != state (*shared))
    return {Status::Busy, {}, {}};
  if (request.sampleCount () < 0 || request.sampleCount () > NTMAX * RX_SAMPLE_RATE)
    return {Status::InvalidRequest, {}, {}};
  if (Request::Kind::Reuse == request.kind_
      && (!completedSamples_ || request.samples_ != completedSamples_))
    return {Status::StaleSamples, {}, {}};
  auto const generation = nextGeneration (lastGeneration_);
  bool const refreshSamples = Request::Kind::Reuse != request.kind_
    || shared->payload.params.nmode != request.mode ()
    || shared->payload.params.ntrperiod != request.options ().ntrperiod;
  bool const published = Request::Kind::Ft8 == request.kind_
    ? publishFt8Mtd (*shared, *request.compact_, generation)
    : publish (*shared, *request.source_, Request::Kind::Snapshot == request.kind_, generation);
  if (!published) return {Status::InvalidRequest, {}, {}};
  lastGeneration_ = generation;
  activeGeneration_ = Generation {generation};
  activeSamples_ = refreshSamples ? SampleIdentity {this, ++lastSamples_}
                                 : completedSamples_;
  return {Status::Ok, activeGeneration_, activeSamples_};
}

bool DecoderIpc::Session::accepts (qint32 generation) const
{
  return generation > 0 && generation == activeGeneration_.value ();
}

DecoderIpc::Status DecoderIpc::Session::complete (Completion const& completion)
{
  if (!accepts (completion.generation)) return Status::StaleGeneration;
  auto * shared = storage ();
  if (!shared) return Status::Unavailable;
  if (!consume (*shared, completion.generation)) return Status::Busy;
  completedSamples_ = activeSamples_;
  activeGeneration_ = {};
  activeSamples_ = {};
  return Status::Ok;
}

DecoderIpc::Diagnostics DecoderIpc::Session::diagnostics () const
{
  auto const * shared = storage ();
  return shared ? Diagnostics {state (*shared), generation (*shared), progress (*shared)}
                : Diagnostics {};
}

void DecoderIpc::Session::abort ()
{
  activeGeneration_ = {};
  activeSamples_ = {};
  completedSamples_ = {};
}

qint32 DecoderIpc::nextGeneration (qint32 current)
{
  return current <= 0 || current == std::numeric_limits<qint32>::max ()
    ? 1 : current + 1;
}

bool DecoderIpc::hasUsableSize (qint64 size)
{
  return size >= static_cast<qint64> (sizeof (shared_dec_data_t));
}

qint32 DecoderIpc::state (shared_dec_data_t const& shared)
{
  return decoder_ipc_atomic_load (&shared.control.state);
}

qint32 DecoderIpc::generation (shared_dec_data_t const& shared)
{
  return decoder_ipc_atomic_load (&shared.control.generation);
}

qint32 DecoderIpc::progress (shared_dec_data_t const& shared)
{
  return decoder_ipc_atomic_load (&shared.control.progress);
}

qint32 DecoderIpc::protocolVersion (shared_dec_data_t const& shared)
{
  return decoder_ipc_atomic_load (&shared.control.version);
}

void DecoderIpc::initialize (shared_dec_data_t& shared)
{
  std::memset (&shared, 0, sizeof (shared));
  decoder_ipc_expected_layout (&shared.layout);
  decoder_ipc_control_initialize (&shared.control.generation, &shared.control.state,
                                  &shared.control.version, &shared.control.progress);
}

void DecoderIpc::shutdown (shared_dec_data_t& shared)
{
  if (hasCurrentProtocol (shared))
    decoder_ipc_control_shutdown (&shared.control.state, &shared.control.version);
}

bool DecoderIpc::publish (shared_dec_data_t& shared, dec_data_t const& payload,
                          bool copySamples, qint32 generation)
{
  if (!hasCurrentProtocol (shared)
      || DECODER_IPC_IDLE != state (shared)
      || generation <= 0)
    {
      return false;
    }

  // A different mode or period must not reuse an incomplete sample snapshot.
  bool const contextChanged = !copySamples
    && (shared.payload.params.nmode != payload.params.nmode
        || shared.payload.params.ntrperiod != payload.params.ntrperiod);
  copySamples = copySamples || contextChanged;
  if (copySamples)
    {
      std::memcpy (shared.payload.ss, payload.ss, sizeof payload.ss);
      std::memcpy (shared.payload.savg, payload.savg, sizeof payload.savg);
      std::memcpy (shared.payload.sred, payload.sred, sizeof payload.sred);
      std::memcpy (shared.payload.d2, payload.d2,
                   sampleCountToCopy (payload.params.ntrperiod) * sizeof payload.d2[0]);
      shared.payload.params = payload.params;
    }
  else
    {
      shared.payload.params = payload.params;
    }
  if (contextChanged)
    {
      shared.payload.params.newdat = true;
      shared.payload.params.nagain = false;
    }
  return decoder_ipc_control_publish (&shared.control.generation,
                                      &shared.control.state,
                                      &shared.control.version,
                                      &shared.control.progress, generation);
}

bool DecoderIpc::publishFt8Mtd (shared_dec_data_t& shared,
                                Ft8MtdPayload const& payload,
                                qint32 generation)
{
  if (!hasCurrentProtocol (shared)
      || DECODER_IPC_IDLE != state (shared)
      || generation <= 0
      || 8 != payload.params.nmode
      || !payload.params.lmultift8)
    {
      return false;
    }

  shared.payload.params = payload.params;
  std::memcpy (shared.payload.d2, payload.samples.data (),
               sizeof payload.samples);
  return decoder_ipc_control_publish (&shared.control.generation,
                                      &shared.control.state,
                                      &shared.control.version,
                                      &shared.control.progress, generation);
}

bool DecoderIpc::claim (shared_dec_data_t& shared, qint32& generation)
{
  return hasCurrentProtocol (shared)
    && DECODER_IPC_CLAIMED == decoder_ipc_control_try_claim (
      &shared.control.generation, &shared.control.state, &shared.control.version,
      &generation);
}

bool DecoderIpc::finish (shared_dec_data_t& shared, qint32 generation)
{
  return hasCurrentProtocol (shared)
    && decoder_ipc_control_finish (&shared.control.generation,
                                     &shared.control.state,
                                     &shared.control.version, generation);
}

bool DecoderIpc::consume (shared_dec_data_t& shared, qint32 generation)
{
  return hasCurrentProtocol (shared)
    && decoder_ipc_control_consume (&shared.control.generation,
                                      &shared.control.state,
                                      &shared.control.version, generation);
}

bool DecoderIpc::parseStart (QByteArray line, qint32 * generation)
{
  if (!generation) return false;
  if (line.endsWith ('\n')) line.chop (1);
  if (line.endsWith ('\r')) line.chop (1);

  QByteArray const prefix {"<DecodeStarted> gen="};
  if (!line.startsWith (prefix)) return false;

  qint32 parsed {0};
  if (!parseGeneration (line.mid (prefix.size ()), parsed)) return false;
  *generation = parsed;
  return true;
}

bool DecoderIpc::parseCompletion (QByteArray line, Completion * completion)
{
  if (!completion) return false;
  if (line.endsWith ('\n')) line.chop (1);
  if (line.endsWith ('\r')) line.chop (1);

  QByteArray const prefix {"<DecodeFinished>"};
  QByteArray const generationPrefix {" gen="};
  constexpr int synchronizedWidth {4};
  constexpr int decodedWidth {4};
  constexpr int averageWidth {9};
  auto const synchronizedOffset = prefix.size ();
  auto const decodedOffset = synchronizedOffset + synchronizedWidth;
  auto const averageOffset = decodedOffset + decodedWidth;
  auto const generationOffset = averageOffset + averageWidth;
  if (!line.startsWith (prefix)
      || line.mid (generationOffset, generationPrefix.size ()) != generationPrefix)
    {
      return false;
    }

  Completion parsed {};
  if (!parseField (line.mid (synchronizedOffset, synchronizedWidth),
                   parsed.synchronized)
      || !parseField (line.mid (decodedOffset, decodedWidth), parsed.decoded)
      || !parseField (line.mid (averageOffset, averageWidth), parsed.average))
    {
      return false;
    }

  auto const generationText = line.mid (generationOffset + generationPrefix.size ());
  if (!parseGeneration (generationText, parsed.generation))
    {
      return false;
    }
  *completion = parsed;
  return true;
}
