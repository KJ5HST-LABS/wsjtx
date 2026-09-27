#ifndef DECODER_IPC_HPP
#define DECODER_IPC_HPP

#include <QByteArray>
#include <QtGlobal>
#include <QSharedMemory>

#include <array>

#include "commons.h"

namespace DecoderIpc
{
  // FT8 reads the complete 15-second buffer even when decoding starts earlier.
  constexpr std::size_t Ft8SampleCount {15 * RX_SAMPLE_RATE};

  struct Ft8MtdPayload
  {
    std::array<short, Ft8SampleCount> samples {};
    decoder_params_t params {};
  };

  struct Completion
  {
    qint32 synchronized;
    qint32 decoded;
    qint32 average;
    qint32 generation;
  };

  class Session;

  class Generation
  {
  public:
    Generation () = default;
    qint32 value () const { return value_; }
  private:
    friend class Session;
    explicit Generation (qint32 value) : value_ {value} {}
    qint32 value_ {0};
  };

  class SampleIdentity
  {
  public:
    SampleIdentity () = default;
    explicit operator bool () const { return owner_ && value_; }
    bool operator== (SampleIdentity const& other) const
    { return owner_ == other.owner_ && value_ == other.value_; }
    bool operator!= (SampleIdentity const& other) const { return !(*this == other); }
  private:
    friend class Session;
    SampleIdentity (Session const * owner, quint64 value)
      : owner_ {owner}, value_ {value} {}
    Session const * owner_ {nullptr};
    quint64 value_ {0};
  };

  // Sources are borrowed only for the duration of synchronous submission.
  class Request
  {
  public:
    static Request snapshot (dec_data_t const& source);
    static Request reuse (dec_data_t const& source, SampleIdentity samples);
    static Request ft8 (Ft8MtdPayload const& source);
    int sampleCount () const { return options ().kin; }
    int mode () const { return options ().nmode; }
    decoder_params_t const& options () const;
  private:
    friend class Session;
    enum class Kind { Snapshot, Reuse, Ft8 };
    Request (Kind kind, dec_data_t const * source,
             Ft8MtdPayload const * compact, SampleIdentity samples = {});
    Kind kind_;
    dec_data_t const * source_;
    Ft8MtdPayload const * compact_;
    SampleIdentity samples_;
  };

  enum class Status { Ok, Unavailable, Busy, InvalidRequest, StaleSamples,
                      StaleGeneration, Incompatible, Orphaned, CreateFailed };

  struct Submission
  {
    Status status {Status::Unavailable};
    Generation generation;
    SampleIdentity samples;
    explicit operator bool () const { return Status::Ok == status; }
  };

  struct Diagnostics
  {
    qint32 state {-1};
    qint32 generation {-1};
    qint32 progress {-1};
  };

  class Session
  {
  public:
    Status open (QString const& key);
    QString errorString () const { return error_; }
    qint64 size () const { return memory_.size (); }
    bool reset ();
    void beginStartup ();
    Status acceptReady (int version);
    bool ready () const { return ready_; }
    void shutdown ();
    void detach ();
    Submission submit (Request const& request);
    SampleIdentity samples () const { return completedSamples_; }
    bool accepts (qint32 generation) const;
    Status complete (Completion const& completion);
    Diagnostics diagnostics () const;
    void abort ();
  private:
    shared_dec_data_t * storage ();
    shared_dec_data_t const * storage () const;
    QSharedMemory memory_;
    QString error_;
    qint32 lastGeneration_ {0};
    Generation activeGeneration_;
    quint64 lastSamples_ {0};
    SampleIdentity activeSamples_;
    SampleIdentity completedSamples_;
    bool ready_ {false};
  };

  qint32 nextGeneration (qint32 current);
  bool hasUsableSize (qint64 size);
  qint32 state (shared_dec_data_t const& shared);
  qint32 generation (shared_dec_data_t const& shared);
  qint32 progress (shared_dec_data_t const& shared);
  qint32 protocolVersion (shared_dec_data_t const& shared);
  void initialize (shared_dec_data_t& shared);
  void shutdown (shared_dec_data_t& shared);
  bool publish (shared_dec_data_t& shared, dec_data_t const& payload,
                bool copySamples, qint32 generation);
  bool publishFt8Mtd (shared_dec_data_t& shared,
                      Ft8MtdPayload const& payload, qint32 generation);
  bool claim (shared_dec_data_t& shared, qint32& generation);
  bool finish (shared_dec_data_t& shared, qint32 generation);
  bool consume (shared_dec_data_t& shared, qint32 generation);
  bool parseStart (QByteArray line, qint32 * generation);
  bool parseCompletion (QByteArray line, Completion * completion);
}

#endif
