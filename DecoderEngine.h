#ifndef WSJTX_DECODER_ENGINE_H
#define WSJTX_DECODER_ENGINE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef void *decoder_engine_handle;
enum { DECODER_ENGINE_ABI = 1, DECODER_MODE_FT8 = 8 };
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
  int32_t abi_version, ft8, cancellation, concurrent_sessions, evidence_capacity;
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
  int64_t input_id, analysis_id;
  int32_t attempt_no, mode, phase, source;
  decoder_ft8_options ft8;
} decoder_attempt_request;

/* Borrowed read-only mono signed PCM. Only sample_count samples are read.
   FT8 currently accepts 12000 Hz and 1..180000 samples. */
typedef struct {
  const int16_t *samples;
  int32_t sample_count, sample_rate_hz;
} decoder_audio_view;

typedef struct {
  int64_t input_id, analysis_id;
  int32_t attempt_no, mode, variant, kind, child_index;
  int32_t snr_db, ap_type, payload_origin, has_tones, has_start, method;
  float frequency_hz, dt_seconds, start_seconds, sync, quality;
  int8_t payload77[77], tones[79], symbols[50];
  char message[38];
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
