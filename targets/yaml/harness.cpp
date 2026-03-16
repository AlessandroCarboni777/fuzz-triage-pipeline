#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

#include <yaml.h>

static bool env_enabled(const char* name) {
    const char* v = std::getenv(name);
    return v &&
           (std::strcmp(v, "1") == 0 ||
            std::strcmp(v, "true") == 0 ||
            std::strcmp(v, "TRUE") == 0);
}

static bool contains_demo_trigger(const char* buf) {
    return std::strstr(buf, "CRASHME") != nullptr;
}

static void trigger_demo_asan_use_after_free() {
    char* p = static_cast<char*>(std::malloc(8));
    if (!p) {
        return;
    }

    std::memset(p, 'A', 8);
    std::free(p);

    volatile char* vp = p;
    *vp = 'X';
}

static void parse_with_event_api(const unsigned char* data, size_t size) {
    yaml_parser_t parser;
    yaml_event_t event;

    if (!yaml_parser_initialize(&parser)) {
        return;
    }

    yaml_parser_set_input_string(&parser, data, size);

    bool done = false;
    int budget = 1024;

    while (!done && budget-- > 0) {
        if (!yaml_parser_parse(&parser, &event)) {
            break;
        }

        switch (event.type) {
            case YAML_STREAM_START_EVENT:
            case YAML_STREAM_END_EVENT:
            case YAML_DOCUMENT_START_EVENT:
            case YAML_DOCUMENT_END_EVENT:
            case YAML_SEQUENCE_START_EVENT:
            case YAML_SEQUENCE_END_EVENT:
            case YAML_MAPPING_START_EVENT:
            case YAML_MAPPING_END_EVENT:
            case YAML_ALIAS_EVENT:
                break;

            case YAML_SCALAR_EVENT:
                if (event.data.scalar.value) {
                    volatile unsigned char first = event.data.scalar.value[0];
                    (void)first;

                    volatile size_t len = event.data.scalar.length;
                    (void)len;
                }
                break;

            case YAML_NO_EVENT:
            default:
                break;
        }

        if (event.type == YAML_STREAM_END_EVENT) {
            done = true;
        }

        yaml_event_delete(&event);
    }

    yaml_parser_delete(&parser);
}

static void walk_document_node(yaml_document_t* document, int index, int depth, int budget) {
    if (!document || index <= 0 || depth > 16 || budget <= 0) {
        return;
    }

    yaml_node_t* node = yaml_document_get_node(document, index);
    if (!node) {
        return;
    }

    switch (node->type) {
        case YAML_SCALAR_NODE: {
            if (node->data.scalar.value) {
                volatile unsigned char first = node->data.scalar.value[0];
                (void)first;

                volatile size_t len = node->data.scalar.length;
                (void)len;
            }
            break;
        }

        case YAML_SEQUENCE_NODE: {
            yaml_node_item_t* item = node->data.sequence.items.start;
            int local_budget = budget - 1;

            while (item && item < node->data.sequence.items.top && local_budget-- > 0) {
                walk_document_node(document, *item, depth + 1, local_budget);
                ++item;
            }
            break;
        }

        case YAML_MAPPING_NODE: {
            yaml_node_pair_t* pair = node->data.mapping.pairs.start;
            int local_budget = budget - 1;

            while (pair && pair < node->data.mapping.pairs.top && local_budget-- > 0) {
                walk_document_node(document, pair->key, depth + 1, local_budget);
                walk_document_node(document, pair->value, depth + 1, local_budget);
                ++pair;
            }
            break;
        }

        case YAML_NO_NODE:
        default:
            break;
    }
}

static void parse_with_document_api(const unsigned char* data, size_t size) {
    yaml_parser_t parser;
    yaml_document_t document;

    if (!yaml_parser_initialize(&parser)) {
        return;
    }

    yaml_parser_set_input_string(&parser, data, size);

    int docs_seen = 0;
    while (docs_seen < 8) {
        if (!yaml_parser_load(&parser, &document)) {
            break;
        }

        yaml_node_t* root = yaml_document_get_root_node(&document);
        if (!root) {
            yaml_document_delete(&document);
            break;
        }

        walk_document_node(&document, 1, 0, 512);
        yaml_document_delete(&document);
        ++docs_seen;
    }

    yaml_parser_delete(&parser);
}

static void emit_static_document() {
    yaml_emitter_t emitter;
    yaml_event_t event;
    unsigned char output[4096];
    size_t written = 0;
    int ok = 1;

    if (!yaml_emitter_initialize(&emitter)) {
        return;
    }

    yaml_emitter_set_output_string(&emitter, output, sizeof(output), &written);
    yaml_emitter_set_unicode(&emitter, 1);

    ok = yaml_stream_start_event_initialize(&event, YAML_UTF8_ENCODING);
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_document_start_event_initialize(&event, nullptr, nullptr, nullptr, 1);
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_mapping_start_event_initialize(
        &event, nullptr, nullptr, 1, YAML_BLOCK_MAPPING_STYLE
    );
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_scalar_event_initialize(
        &event, nullptr, nullptr,
        reinterpret_cast<yaml_char_t*>(const_cast<char*>("name")),
        4, 1, 1, YAML_PLAIN_SCALAR_STYLE
    );
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_scalar_event_initialize(
        &event, nullptr, nullptr,
        reinterpret_cast<yaml_char_t*>(const_cast<char*>("fuzzpipe")),
        8, 1, 1, YAML_PLAIN_SCALAR_STYLE
    );
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_scalar_event_initialize(
        &event, nullptr, nullptr,
        reinterpret_cast<yaml_char_t*>(const_cast<char*>("items")),
        5, 1, 1, YAML_PLAIN_SCALAR_STYLE
    );
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_sequence_start_event_initialize(
        &event, nullptr, nullptr, 1, YAML_FLOW_SEQUENCE_STYLE
    );
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_scalar_event_initialize(
        &event, nullptr, nullptr,
        reinterpret_cast<yaml_char_t*>(const_cast<char*>("a")),
        1, 1, 1, YAML_PLAIN_SCALAR_STYLE
    );
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_scalar_event_initialize(
        &event, nullptr, nullptr,
        reinterpret_cast<yaml_char_t*>(const_cast<char*>("b")),
        1, 1, 1, YAML_PLAIN_SCALAR_STYLE
    );
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_sequence_end_event_initialize(&event);
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_mapping_end_event_initialize(&event);
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_document_end_event_initialize(&event, 1);
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    if (ok) ok = yaml_stream_end_event_initialize(&event);
    if (ok) ok = yaml_emitter_emit(&emitter, &event);

    yaml_emitter_delete(&emitter);
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size == 0 || size > 65536) {
        return 0;
    }

    char* buf = static_cast<char*>(std::malloc(size + 1));
    if (!buf) {
        return 0;
    }

    std::memcpy(buf, data, size);
    buf[size] = '\0';

    if (env_enabled("FUZZPIPE_DEMO_CRASH") && contains_demo_trigger(buf)) {
        trigger_demo_asan_use_after_free();
        std::free(buf);
        return 0;
    }

    const unsigned char* udata =
        reinterpret_cast<const unsigned char*>(buf);

    parse_with_event_api(udata, size);
    parse_with_document_api(udata, size);
    emit_static_document();

    std::free(buf);
    return 0;
}
