#ifndef WSJTX_DECODER_ENGINE_H
#define WSJTX_DECODER_ENGINE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef void *decoder_engine_handle;
enum { DECODER_ENGINE_ABI = 4, DECODER_MODE_FT4 = 5, DECODER_MODE_FT8 = 8, DECODER_MODE_JT9 = 9 };
enum { DECODER_SUPPORT_FT8 = 1, DECODER_SUPPORT_FT4 = 2, DECODER_SUPPORT_JT9 = 4 };
enum { DECODER_OK = 0, DECODER_INVALID = 1, DECODER_BUSY = 2,
       DECODER_UNSUPPORTED = 3, DECODER_CAPACITY = 4 };
enum { DECODER_PHASE_EARLY = 1, DECODER_PHASE_NORMAL = 2, DECODER_PHASE_REPEAT = 3 };
enum { DECODER_SOURCE_LIVE = 0, DECODER_SOURCE_FILE = 1 };
enum { DECODER_FT8_CLASSIC = 0, DECODER_FT8_MTD = 1, DECODER_FT8_SUPERFOX = 2 };
enum { DECODER_PAYLOAD_NONE = 0, DECODER_PAYLOAD_DECODED = 1, DECODER_PAYLOAD_HYPOTHESIS = 2 };
enum { DECODER_SUPERFOX_CQ = 1, DECODER_SUPERFOX_EXCHANGE = 2,
       DECODER_SUPERFOX_FREE_TEXT = 3, DECODER_SUPERFOX_VERIFICATION = 4 };

typedef struct {
  int32_t abi_version;
} decoder_engine_options;

typedef struct {
  /* supported_modes is a bitmask of DECODER_SUPPORT_* values. */
  int32_t abi_version, supported_modes, cancellation, concurrent_sessions, evidence_capacity;
} decoder_engine_capabilities;

/* Option records use fixed-width, space-padded calls and grids. Booleans are 0 or 1.
   half_symbol_stage is the FT8 processing stage (41..50), independent of repeat
   intent and the number of available audio samples. */
typedef struct {
  int32_t half_symbol_stage;
  int32_t reuse_spectrum;
  int32_t utc;
  int32_t qso_progress;
  int32_t receive_frequency_hz;
  int32_t transmit_frequency_hz;
  int32_t search_low_hz;
  int32_t search_high_hz;
  int32_t tolerance_hz;
  int32_t depth;
  int32_t ap_width_hz;
  int32_t contest;
  int32_t candidate_thinning;
  int32_t time_center;
  int32_t cycles;
  int32_t trials;
  int32_t last_transmit;
  int32_t delay;
  int32_t threads;
  int32_t receive_sensitivity;
  int32_t discard_leading_seconds;
  int32_t date;
  int32_t ap_enabled;
  int32_t cq_only;
  int32_t even_sequence;
  int32_t superfox;
  int32_t filtered_retry;
  int32_t stop_hint;
  int32_t mtd;
  int32_t low_threshold;
  int32_t subtract_pass;
  int32_t transmitting;
  int32_t hide_duplicates;
  int32_t hound;
  int32_t standard_mycall;
  int32_t standard_hiscall;
  int32_t ap_mycall;
  int32_t mode_changed;
  int32_t band_changed;
  int32_t dx_search;
  int32_t wide_dx_search;
  int32_t multiple_instances;
  int32_t skip_first_message;
  float eme_delay_seconds;
  char mycall[12];
  char my_base_call[12];
  char hiscall[12];
  char his_base_call[12];
  char mygrid[6];
  char hisgrid[6];
} decoder_ft8_options;

typedef struct {
  int32_t utc;
  int32_t qso_progress;
  int32_t receive_frequency_hz;
  int32_t search_low_hz;
  int32_t search_high_hz;
  int32_t depth;
  int32_t cq_only;
  int32_t contest;
  char mycall[12];
  char hiscall[12];
} decoder_ft4_options;

/* Slow JT9A-H use one-minute periods; submode 0..7 selects A..H.
   Decoding spectra are prepared internally, independently of display settings. */
typedef struct {
  int32_t utc;
  int32_t receive_frequency_hz;
  int32_t search_low_hz;
  int32_t search_high_hz;
  int32_t tolerance_hz;
  int32_t depth;
  int32_t submode;
} decoder_jt9_options;

/* Only the options for mode are read. EARLY is an FT8 phase; FT4 and JT9 use
   NORMAL or REPEAT. Mode support is reported by supported_modes. */
typedef struct {
  int64_t input_id, analysis_id;
  int32_t attempt_no, mode, phase, source;
  decoder_ft8_options ft8;
  decoder_ft4_options ft4;
  decoder_jt9_options jt9;
} decoder_attempt_request;

/* Borrowed read-only mono signed PCM. Only sample_count samples are read.
   All modes accept 12000 Hz. FT8 accepts 1..180000 samples;
   FT4 accepts 1..72576 samples (its analysis window within a 7.5-second period).
   Slow JT9 accepts 1..720000 samples (a one-minute period).
   Short inputs are zero-padded. Release input before changing its identity or mode. */
typedef struct {
  const int16_t *samples;
  int32_t sample_count, sample_rate_hz;
} decoder_audio_view;

/* waveform_start_seconds places sample zero of the reference waveform in
   the identified input, before any engine cropping, and may be negative.
   It is an estimate, not a record of a subsequent subtraction refinement.
   frequency_hz is the reference waveform's tone-zero frequency.

   FT8: 79 GFSK symbols, 1920 samples/symbol at 12 kHz, BT=2; the
   gen_ft8wave template includes its edge ramps within those 79 symbols.
   FT4: 103 GFSK tones, 576 samples/symbol at 12 kHz, BT=1; the
   gen_ft4wave template includes an additional leading and trailing ramp
   interval, totaling 105 symbol intervals. Its start precedes the first
   synchronization-symbol reference by one symbol (0.048 seconds).
   Both origins are template sample zero, independent of initial amplitude.
   Payload bits are canonical message bits, before mode-specific scrambling. */
typedef struct {
  int8_t payload77[77], tones[79];
  int32_t payload_origin, has_tones, has_waveform_start, method;
  float waveform_start_seconds;
} decoder_ft8_evidence;

typedef struct {
  int8_t payload77[77], tones[103];
  int32_t payload_origin, has_tones, has_waveform_start, method;
  float waveform_start_seconds;
} decoder_ft4_evidence;

typedef struct {
  int8_t symbols[50];
  int32_t kind, child_index;
} decoder_superfox_evidence;

/* Drift is quantized by the JT9A estimator to 12000/16384 Hz over
   its 48.96-second analysis span, then expressed here in Hz/minute.
   JT9B-H do not estimate drift and leave has_drift zero. */
typedef struct {
  int32_t has_drift;
  float drift_hz_per_minute;
} decoder_jt9_result;

/* dt_seconds retains the mode's operator-facing DT convention. Use the
   evidence's waveform_start_seconds for reconstruction when available.
   mode and variant select ft8, ft4, superfox, or jt9; inactive records are zero.
   JT9 variant is its submode (0..7 for A..H); JT9 has no 77-bit evidence.
   Availability flags and payload_origin govern fields in the active record. */
typedef struct {
  int64_t input_id, analysis_id;
  int32_t attempt_no, mode, variant;
  int32_t snr_db, ap_type;
  float frequency_hz, dt_seconds, sync, quality;
  char message[38];
  decoder_ft8_evidence ft8;
  decoder_ft4_evidence ft4;
  decoder_superfox_evidence superfox;
  decoder_jt9_result jt9;
} decoder_observation;

typedef struct {
  int32_t status, observation_count, retained_count, evidence_dropped;
} decoder_attempt_outcome;

/* One session per process, with lifecycle and decode calls confined to one thread.
   Callbacks are serialized and borrowed until return; copy records to retain them.
   Mutating engine calls during a callback return DECODER_BUSY. */
typedef void (*decoder_observation_callback)(const decoder_observation *, void *);

int32_t decoder_engine_create(const decoder_engine_options *, decoder_engine_handle *);
int32_t decoder_engine_get_capabilities(decoder_engine_handle, decoder_engine_capabilities *);
int32_t decoder_engine_decode(decoder_engine_handle, const decoder_attempt_request *,
                             const decoder_audio_view *, decoder_observation_callback,
                             void *, decoder_attempt_outcome *);
int32_t decoder_engine_release_input(decoder_engine_handle, int64_t input_id);
int32_t decoder_engine_reset_session(decoder_engine_handle);
int32_t decoder_engine_destroy(decoder_engine_handle);

#ifdef __cplusplus
}
#endif
#endif
