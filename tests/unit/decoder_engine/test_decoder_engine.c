#include "DecoderEngine.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(condition) do { \
  if (!(condition)) { \
    fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition); \
    exit(EXIT_FAILURE); \
  } \
} while (0)

extern void decoder_engine_test_signal(int16_t samples[180000], int8_t payload[77]);
extern void decoder_engine_test_residual(float samples[180000]);
extern void decoder_engine_test_host_windows(void);

typedef struct {
  decoder_engine_handle engine;
  const decoder_attempt_request *request;
  const decoder_audio_view *audio;
  int count;
  int found_expected;
  int8_t expected_payload[77];
  decoder_observation retained;
  decoder_observation expected_record;
} callback_context;

static void observe(const decoder_observation *record, void *opaque)
{
  callback_context *context = opaque;
  decoder_attempt_outcome outcome;
  CHECK(record->input_id == context->request->input_id);
  CHECK(record->analysis_id == context->request->analysis_id);
  CHECK(record->attempt_no == context->request->attempt_no);
  CHECK(record->mode == DECODER_MODE_FT8);
  ++context->count;
  context->retained = *record;

  if (strcmp(record->message, "CQ K1JT FN20") == 0) {
    CHECK(record->payload_origin == DECODER_PAYLOAD_DECODED);
    CHECK(memcmp(record->payload77, context->expected_payload, 77) == 0);
    CHECK(record->has_tones != 0);
    CHECK(record->has_start != 0);
    context->expected_record = *record;
    ++context->found_expected;
  }

  CHECK(decoder_engine_release_input(context->engine, record->input_id) == DECODER_BUSY);
  CHECK(decoder_engine_reset_session(context->engine) == DECODER_BUSY);
  CHECK(decoder_engine_destroy(context->engine) == DECODER_BUSY);
  CHECK(decoder_engine_decode(context->engine, context->request, context->audio,
                             observe, context, &outcome) == DECODER_BUSY);
}

static decoder_attempt_request request_for(int64_t input_id, int64_t analysis_id)
{
  decoder_attempt_request request = {0};
  request.input_id = input_id;
  request.analysis_id = analysis_id;
  request.attempt_no = 1;
  request.mode = DECODER_MODE_FT8;
  request.phase = DECODER_PHASE_NORMAL;
  request.source = DECODER_SOURCE_FILE;
  request.ft8.half_symbol_stage = 50;
  request.ft8.utc = 120000;
  request.ft8.receive_frequency_hz = 1500;
  request.ft8.transmit_frequency_hz = 1500;
  request.ft8.search_low_hz = 200;
  request.ft8.search_high_hz = 4000;
  request.ft8.tolerance_hz = 20;
  request.ft8.depth = 3;
  request.ft8.ap_width_hz = 75;
  request.ft8.cycles = 1;
  request.ft8.threads = 1;
  request.ft8.discard_leading_seconds = 0;
  request.ft8.date = 260928;
  memset(request.ft8.mycall, ' ', sizeof request.ft8.mycall);
  memset(request.ft8.my_base_call, ' ', sizeof request.ft8.my_base_call);
  memset(request.ft8.hiscall, ' ', sizeof request.ft8.hiscall);
  memset(request.ft8.his_base_call, ' ', sizeof request.ft8.his_base_call);
  memset(request.ft8.mygrid, ' ', sizeof request.ft8.mygrid);
  memset(request.ft8.hisgrid, ' ', sizeof request.ft8.hisgrid);
  return request;
}

static void decode_signal(callback_context *context, const int16_t *original,
                          decoder_attempt_outcome *outcome)
{
  context->count = 0;
  context->found_expected = 0;
  CHECK(decoder_engine_decode(context->engine, context->request, context->audio,
                             observe, context, outcome) == DECODER_OK);
  CHECK(outcome->status == DECODER_OK);
  CHECK(context->found_expected > 0);
  CHECK(context->count == outcome->observation_count);
  CHECK(outcome->retained_count > 0 && outcome->evidence_dropped == 0);
  CHECK(memcmp(context->audio->samples, original, 180000 * sizeof *original) == 0);
}

static void check_same_result(const callback_context *context,
                              const decoder_observation *reference, int count)
{
  CHECK(context->count == count);
  CHECK(strcmp(context->expected_record.message, reference->message) == 0);
  CHECK(context->expected_record.variant == reference->variant);
  CHECK(context->expected_record.payload_origin == reference->payload_origin);
  CHECK(memcmp(context->expected_record.payload77, reference->payload77, 77) == 0);
  CHECK(memcmp(context->expected_record.tones, reference->tones, 79) == 0);
}

static void check_reset_and_recreate(callback_context *context,
                                    decoder_attempt_request *request,
                                    const int16_t *original,
                                    const decoder_engine_options *options,
                                    decoder_attempt_outcome *outcome)
{
  decoder_observation reference = context->expected_record;
  int reference_count = context->count;
  CHECK(decoder_engine_reset_session(context->engine) == DECODER_OK);
  ++request->input_id;
  ++request->analysis_id;
  decode_signal(context, original, outcome);
  check_same_result(context, &reference, reference_count);
  CHECK(decoder_engine_destroy(context->engine) == DECODER_OK);
  CHECK(decoder_engine_create(options, &context->engine) == DECODER_OK);
  ++request->input_id;
  ++request->analysis_id;
  decode_signal(context, original, outcome);
  check_same_result(context, &reference, reference_count);
}

static void check_repeat_stages(callback_context *context, const int16_t *original)
{
  decoder_attempt_request request = request_for(701, 801);
  decoder_attempt_outcome outcome;
  context->request = &request;
  request.phase = DECODER_PHASE_REPEAT;
  request.ft8.depth = 1;
  CHECK(decoder_engine_reset_session(context->engine) == DECODER_OK);
  for (int stage = 41; stage < 50; ++stage) {
    request.ft8.half_symbol_stage = stage;
    ++request.attempt_no;
    CHECK(decoder_engine_decode(context->engine, &request, context->audio,
                               NULL, NULL, &outcome) == DECODER_OK);
    CHECK(outcome.observation_count == 0);
  }
  request.ft8.half_symbol_stage = 50;
  ++request.attempt_no;
  decode_signal(context, original, &outcome);
}

static void check_mtd_residual_retention(callback_context *context,
                                        decoder_attempt_request *request)
{
  float *saved = malloc(180000 * sizeof *saved);
  float *current = malloc(180000 * sizeof *current);
  decoder_attempt_outcome outcome;
  int changed = 0;
  CHECK(saved != NULL && current != NULL);
  decoder_engine_test_residual(saved);
  for (int i = 0; i < 180000; ++i)
    changed |= saved[i] != context->audio->samples[i];
  CHECK(changed);

  /* Stop after input preparation so the next pass cannot change the residual. */
  request->ft8.filtered_retry = 1;
  request->ft8.receive_frequency_hz = 3000;
  request->ft8.search_low_hz = 1000;
  request->ft8.search_high_hz = 2000;
  request->phase = DECODER_PHASE_REPEAT;
  ++request->attempt_no;
  CHECK(decoder_engine_decode(context->engine, request, context->audio,
                             NULL, NULL, &outcome) == DECODER_OK);
  decoder_engine_test_residual(current);
  CHECK(memcmp(saved, current, 180000 * sizeof *saved) == 0);

  request->source = DECODER_SOURCE_LIVE;
  ++request->attempt_no;
  CHECK(decoder_engine_decode(context->engine, request, context->audio,
                             NULL, NULL, &outcome) == DECODER_OK);
  decoder_engine_test_residual(current);
  for (int i = 0; i < 180000; ++i)
    CHECK(current[i] == context->audio->samples[i]);

  for (int reset = 0; reset <= 1; ++reset) {
    request->phase = DECODER_PHASE_NORMAL;
    request->source = DECODER_SOURCE_FILE;
    request->ft8.filtered_retry = 0;
    request->ft8.receive_frequency_hz = 1500;
    request->ft8.search_low_hz = 200;
    request->ft8.search_high_hz = 4000;
    ++request->attempt_no;
    CHECK(decoder_engine_decode(context->engine, request, context->audio,
                               NULL, NULL, &outcome) == DECODER_OK);
    decoder_engine_test_residual(current);
    changed = 0;
    for (int i = 0; i < 180000; ++i)
      changed |= current[i] != context->audio->samples[i];
    CHECK(changed);
    if (reset)
      CHECK(decoder_engine_reset_session(context->engine) == DECODER_OK);
    else
      CHECK(decoder_engine_release_input(context->engine, request->input_id) == DECODER_OK);
    ++request->input_id;
    ++request->analysis_id;
    request->attempt_no = 1;
    request->source = DECODER_SOURCE_FILE;
    request->phase = DECODER_PHASE_REPEAT;
    request->ft8.filtered_retry = 1;
    request->ft8.receive_frequency_hz = 3000;
    request->ft8.search_low_hz = 1000;
    request->ft8.search_high_hz = 2000;
    CHECK(decoder_engine_decode(context->engine, request, context->audio,
                               NULL, NULL, &outcome) == DECODER_OK);
    decoder_engine_test_residual(current);
    for (int i = 0; i < 180000; ++i)
      CHECK(current[i] == context->audio->samples[i]);
  }
  free(current);
  free(saved);
}

int main(void)
{
  decoder_engine_options options = {DECODER_ENGINE_ABI};
  decoder_engine_handle engine = NULL, second = NULL;
  decoder_engine_capabilities capabilities;
  decoder_attempt_request request = request_for(101, 201);
  decoder_attempt_outcome outcome;
  int16_t *samples = calloc(180000, sizeof *samples);
  int16_t *before = calloc(180000, sizeof *before);
  decoder_audio_view audio = {samples, 180000, 12000};
  callback_context context = {0};
  CHECK(samples != NULL && before != NULL);

  CHECK(decoder_engine_create(&options, &engine) == DECODER_OK);
  CHECK(engine != NULL);
  CHECK(decoder_engine_create(&options, &second) == DECODER_BUSY);
  CHECK(decoder_engine_get_capabilities(engine, &capabilities) == DECODER_OK);
  CHECK(capabilities.abi_version == DECODER_ENGINE_ABI);
  CHECK(capabilities.ft8 != 0);
  CHECK(capabilities.cancellation == 0);
  CHECK(capabilities.concurrent_sessions == 0);
  CHECK(capabilities.evidence_capacity == 1024);

  context.engine = engine;
  context.request = &request;
  context.audio = &audio;
  request.mode = 65;
  CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_UNSUPPORTED);
  request.mode = DECODER_MODE_FT8;
  audio.sample_rate_hz = 48000;
  CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_UNSUPPORTED);
  audio.sample_rate_hz = 12000;
  audio.sample_count = 180001;
  CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_INVALID);
  audio.sample_count = 0;
  CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_INVALID);
  audio.sample_count = 180000;
  for (int stage = 40; stage <= 51; stage += 11) {
    request.ft8.half_symbol_stage = stage;
    CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_INVALID);
  }
  request.ft8.half_symbol_stage = 50;
  CHECK(context.count == 0);

  CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_OK);
  CHECK(outcome.status == DECODER_OK);
  CHECK(outcome.observation_count == 0 && context.count == 0);
  CHECK(outcome.retained_count == 0 && outcome.evidence_dropped == 0);
  CHECK(memcmp(samples, before, 180000 * sizeof *samples) == 0);
  CHECK(decoder_engine_release_input(engine, request.input_id) == DECODER_OK);

  decoder_engine_test_signal(samples, context.expected_payload);
  memcpy(before, samples, 180000 * sizeof *samples);
  request = request_for(102, 202);
  decode_signal(&context, before, &outcome);

  /* A different reception cannot silently replace retained input state. */
  request.input_id = 103;
  CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_INVALID);
  CHECK(decoder_engine_release_input(engine, 102) == DECODER_OK);
  CHECK(context.retained.input_id == 102);
  CHECK(context.retained.analysis_id == 202);

  memset(samples, 0, 180000 * sizeof *samples);
  context.count = 0;
  request = request_for(103, 203);
  CHECK(decoder_engine_decode(engine, &request, &audio, observe, &context, &outcome) == DECODER_OK);
  CHECK(outcome.observation_count == 0 && context.count == 0);
  CHECK(outcome.retained_count == 0);
  CHECK(decoder_engine_reset_session(engine) == DECODER_OK);
  memcpy(samples, before, 180000 * sizeof *samples);
  request = request_for(104, 204);
  decode_signal(&context, before, &outcome);
  check_reset_and_recreate(&context, &request, before, &options, &outcome);

  check_repeat_stages(&context, before);
  context.request = &request;
  CHECK(decoder_engine_reset_session(context.engine) == DECODER_OK);
  request = request_for(301, 401);
  request.ft8.mtd = 1;
  request.ft8.threads = 2;
  request.ft8.candidate_thinning = 100;
  request.ft8.receive_sensitivity = 3;
  request.ft8.cycles = 3;
  request.ft8.low_threshold = 1;
  request.ft8.subtract_pass = 1;
  request.ft8.wide_dx_search = 1;
  decode_signal(&context, before, &outcome);
  CHECK(context.expected_record.variant == DECODER_FT8_MTD);
  check_reset_and_recreate(&context, &request, before, &options, &outcome);
  check_mtd_residual_retention(&context, &request);
  request.phase = DECODER_PHASE_NORMAL;
  request.ft8.filtered_retry = 0;
  request.ft8.receive_frequency_hz = 1500;
  request.ft8.search_low_hz = 200;
  request.ft8.search_high_hz = 4000;
  CHECK(decoder_engine_destroy(context.engine) == DECODER_OK);
  decoder_engine_test_host_windows();
  free(before);
  free(samples);
  return EXIT_SUCCESS;
}
