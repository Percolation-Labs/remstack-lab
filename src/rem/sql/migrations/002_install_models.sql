-- REM Model Schema (install_models.sql)
-- Generated from Pydantic models
-- Source: model registry
-- Generated at: 2025-11-29T22:17:33.149988
--
-- DO NOT EDIT MANUALLY - Regenerate with: rem db schema generate
--
-- This script creates:
-- 1. Primary entity tables
-- 2. Embeddings tables (embeddings_<table>)
-- 3. KV_STORE triggers for cache maintenance
-- 4. Indexes (foreground only, background indexes separate)
-- 5. Schema table entries (for agent-like table access)

-- ============================================================================
-- PREREQUISITES CHECK
-- ============================================================================

DO $$
BEGIN
    -- Check that install.sql has been run
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'kv_store') THEN
        RAISE EXCEPTION 'KV_STORE table not found. Run migrations/001_install.sql first.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        RAISE EXCEPTION 'pgvector extension not found. Run migrations/001_install.sql first.';
    END IF;

    RAISE NOTICE 'Prerequisites check passed';
END $$;

-- ======================================================================
-- FEEDBACKS (Model: Feedback)
-- ======================================================================

CREATE TABLE IF NOT EXISTS feedbacks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    session_id VARCHAR(256) NOT NULL,
    message_id VARCHAR(256),
    rating INTEGER,
    categories TEXT[] DEFAULT ARRAY[]::TEXT[],
    comment TEXT,
    trace_id VARCHAR(256),
    span_id VARCHAR(256),
    phoenix_synced BOOLEAN,
    phoenix_annotation_id VARCHAR(256),
    annotator_kind VARCHAR(256),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_feedbacks_tenant ON feedbacks (tenant_id);
CREATE INDEX idx_feedbacks_user ON feedbacks (user_id);
CREATE INDEX idx_feedbacks_graph_edges ON feedbacks USING GIN (graph_edges);
CREATE INDEX idx_feedbacks_metadata ON feedbacks USING GIN (metadata);
CREATE INDEX idx_feedbacks_tags ON feedbacks USING GIN (tags);

-- KV_STORE trigger for feedbacks
-- Trigger function to maintain KV_STORE for feedbacks
CREATE OR REPLACE FUNCTION fn_feedbacks_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.id::VARCHAR,
            'feedbacks',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_feedbacks_kv_store ON feedbacks;
CREATE TRIGGER trg_feedbacks_kv_store
AFTER INSERT OR UPDATE OR DELETE ON feedbacks
FOR EACH ROW EXECUTE FUNCTION fn_feedbacks_kv_store_upsert();

-- ======================================================================
-- FILES (Model: File)
-- ======================================================================

CREATE TABLE IF NOT EXISTS files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256) NOT NULL,
    uri VARCHAR(256) NOT NULL,
    content TEXT,
    timestamp VARCHAR(256),
    size_bytes INTEGER,
    mime_type VARCHAR(256),
    processing_status VARCHAR(256),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_files_tenant ON files (tenant_id);
CREATE INDEX idx_files_user ON files (user_id);
CREATE INDEX idx_files_graph_edges ON files USING GIN (graph_edges);
CREATE INDEX idx_files_metadata ON files USING GIN (metadata);
CREATE INDEX idx_files_tags ON files USING GIN (tags);

-- Embeddings for files
CREATE TABLE IF NOT EXISTS embeddings_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_files_entity ON embeddings_files (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_files_field_provider ON embeddings_files (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_files_vector_hnsw ON embeddings_files
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for files
-- Trigger function to maintain KV_STORE for files
CREATE OR REPLACE FUNCTION fn_files_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.id::VARCHAR,
            'files',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_files_kv_store ON files;
CREATE TRIGGER trg_files_kv_store
AFTER INSERT OR UPDATE OR DELETE ON files
FOR EACH ROW EXECUTE FUNCTION fn_files_kv_store_upsert();

-- ======================================================================
-- IMAGE_RESOURCES (Model: ImageResource)
-- ======================================================================

CREATE TABLE IF NOT EXISTS image_resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256),
    uri VARCHAR(256),
    ordinal INTEGER,
    content TEXT,
    timestamp TIMESTAMP,
    category VARCHAR(256),
    related_entities JSONB DEFAULT '{}'::jsonb,
    image_width INTEGER,
    image_height INTEGER,
    image_format VARCHAR(256),
    vision_description TEXT,
    vision_provider VARCHAR(256),
    vision_model VARCHAR(256),
    clip_embedding JSONB,
    clip_dimensions INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_image_resources_tenant ON image_resources (tenant_id);
CREATE INDEX idx_image_resources_user ON image_resources (user_id);
CREATE INDEX idx_image_resources_graph_edges ON image_resources USING GIN (graph_edges);
CREATE INDEX idx_image_resources_metadata ON image_resources USING GIN (metadata);
CREATE INDEX idx_image_resources_tags ON image_resources USING GIN (tags);

-- Embeddings for image_resources
CREATE TABLE IF NOT EXISTS embeddings_image_resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES image_resources(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_image_resources_entity ON embeddings_image_resources (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_image_resources_field_provider ON embeddings_image_resources (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_image_resources_vector_hnsw ON embeddings_image_resources
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for image_resources
-- Trigger function to maintain KV_STORE for image_resources
CREATE OR REPLACE FUNCTION fn_image_resources_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.name::VARCHAR,
            'image_resources',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_image_resources_kv_store ON image_resources;
CREATE TRIGGER trg_image_resources_kv_store
AFTER INSERT OR UPDATE OR DELETE ON image_resources
FOR EACH ROW EXECUTE FUNCTION fn_image_resources_kv_store_upsert();

-- ======================================================================
-- MESSAGES (Model: Message)
-- ======================================================================

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    content TEXT NOT NULL,
    message_type VARCHAR(256),
    session_id VARCHAR(256),
    prompt TEXT,
    model VARCHAR(256),
    token_count INTEGER,
    trace_id VARCHAR(256),
    span_id VARCHAR(256),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_messages_tenant ON messages (tenant_id);
CREATE INDEX idx_messages_user ON messages (user_id);
CREATE INDEX idx_messages_graph_edges ON messages USING GIN (graph_edges);
CREATE INDEX idx_messages_metadata ON messages USING GIN (metadata);
CREATE INDEX idx_messages_tags ON messages USING GIN (tags);

-- Embeddings for messages
CREATE TABLE IF NOT EXISTS embeddings_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_messages_entity ON embeddings_messages (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_messages_field_provider ON embeddings_messages (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_messages_vector_hnsw ON embeddings_messages
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for messages
-- Trigger function to maintain KV_STORE for messages
CREATE OR REPLACE FUNCTION fn_messages_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.id::VARCHAR,
            'messages',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_messages_kv_store ON messages;
CREATE TRIGGER trg_messages_kv_store
AFTER INSERT OR UPDATE OR DELETE ON messages
FOR EACH ROW EXECUTE FUNCTION fn_messages_kv_store_upsert();

-- ======================================================================
-- MOMENTS (Model: Moment)
-- ======================================================================

CREATE TABLE IF NOT EXISTS moments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256),
    moment_type VARCHAR(256),
    category VARCHAR(256),
    starts_timestamp TIMESTAMP NOT NULL,
    ends_timestamp TIMESTAMP,
    present_persons JSONB DEFAULT '{}'::jsonb,
    emotion_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    topic_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    summary TEXT,
    source_resource_ids TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_moments_tenant ON moments (tenant_id);
CREATE INDEX idx_moments_user ON moments (user_id);
CREATE INDEX idx_moments_graph_edges ON moments USING GIN (graph_edges);
CREATE INDEX idx_moments_metadata ON moments USING GIN (metadata);
CREATE INDEX idx_moments_tags ON moments USING GIN (tags);

-- Embeddings for moments
CREATE TABLE IF NOT EXISTS embeddings_moments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES moments(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_moments_entity ON embeddings_moments (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_moments_field_provider ON embeddings_moments (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_moments_vector_hnsw ON embeddings_moments
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for moments
-- Trigger function to maintain KV_STORE for moments
CREATE OR REPLACE FUNCTION fn_moments_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.name::VARCHAR,
            'moments',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_moments_kv_store ON moments;
CREATE TRIGGER trg_moments_kv_store
AFTER INSERT OR UPDATE OR DELETE ON moments
FOR EACH ROW EXECUTE FUNCTION fn_moments_kv_store_upsert();

-- ======================================================================
-- ONTOLOGIES (Model: Ontology)
-- ======================================================================

CREATE TABLE IF NOT EXISTS ontologies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256) NOT NULL,
    file_id UUID NOT NULL,
    agent_schema_id VARCHAR(256) NOT NULL,
    provider_name VARCHAR(256) NOT NULL,
    model_name VARCHAR(256) NOT NULL,
    extracted_data JSONB NOT NULL,
    confidence_score DOUBLE PRECISION,
    extraction_timestamp VARCHAR(256),
    embedding_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_ontologies_tenant ON ontologies (tenant_id);
CREATE INDEX idx_ontologies_user ON ontologies (user_id);
CREATE INDEX idx_ontologies_graph_edges ON ontologies USING GIN (graph_edges);
CREATE INDEX idx_ontologies_metadata ON ontologies USING GIN (metadata);
CREATE INDEX idx_ontologies_tags ON ontologies USING GIN (tags);

-- KV_STORE trigger for ontologies
-- Trigger function to maintain KV_STORE for ontologies
CREATE OR REPLACE FUNCTION fn_ontologies_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.id::VARCHAR,
            'ontologies',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_ontologies_kv_store ON ontologies;
CREATE TRIGGER trg_ontologies_kv_store
AFTER INSERT OR UPDATE OR DELETE ON ontologies
FOR EACH ROW EXECUTE FUNCTION fn_ontologies_kv_store_upsert();

-- ======================================================================
-- ONTOLOGY_CONFIGS (Model: OntologyConfig)
-- ======================================================================

CREATE TABLE IF NOT EXISTS ontology_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256) NOT NULL,
    agent_schema_id VARCHAR(256) NOT NULL,
    description TEXT,
    mime_type_pattern VARCHAR(256),
    uri_pattern VARCHAR(256),
    tag_filter TEXT[],
    priority INTEGER,
    enabled BOOLEAN,
    provider_name VARCHAR(256),
    model_name VARCHAR(256),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_ontology_configs_tenant ON ontology_configs (tenant_id);
CREATE INDEX idx_ontology_configs_user ON ontology_configs (user_id);
CREATE INDEX idx_ontology_configs_graph_edges ON ontology_configs USING GIN (graph_edges);
CREATE INDEX idx_ontology_configs_metadata ON ontology_configs USING GIN (metadata);
CREATE INDEX idx_ontology_configs_tags ON ontology_configs USING GIN (tags);

-- Embeddings for ontology_configs
CREATE TABLE IF NOT EXISTS embeddings_ontology_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES ontology_configs(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_ontology_configs_entity ON embeddings_ontology_configs (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_ontology_configs_field_provider ON embeddings_ontology_configs (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_ontology_configs_vector_hnsw ON embeddings_ontology_configs
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for ontology_configs
-- Trigger function to maintain KV_STORE for ontology_configs
CREATE OR REPLACE FUNCTION fn_ontology_configs_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.id::VARCHAR,
            'ontology_configs',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_ontology_configs_kv_store ON ontology_configs;
CREATE TRIGGER trg_ontology_configs_kv_store
AFTER INSERT OR UPDATE OR DELETE ON ontology_configs
FOR EACH ROW EXECUTE FUNCTION fn_ontology_configs_kv_store_upsert();

-- ======================================================================
-- RESOURCES (Model: Resource)
-- ======================================================================

CREATE TABLE IF NOT EXISTS resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256),
    uri VARCHAR(256),
    ordinal INTEGER,
    content TEXT,
    timestamp TIMESTAMP,
    category VARCHAR(256),
    related_entities JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_resources_tenant ON resources (tenant_id);
CREATE INDEX idx_resources_user ON resources (user_id);
CREATE INDEX idx_resources_graph_edges ON resources USING GIN (graph_edges);
CREATE INDEX idx_resources_metadata ON resources USING GIN (metadata);
CREATE INDEX idx_resources_tags ON resources USING GIN (tags);

-- Embeddings for resources
CREATE TABLE IF NOT EXISTS embeddings_resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_resources_entity ON embeddings_resources (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_resources_field_provider ON embeddings_resources (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_resources_vector_hnsw ON embeddings_resources
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for resources
-- Trigger function to maintain KV_STORE for resources
CREATE OR REPLACE FUNCTION fn_resources_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.name::VARCHAR,
            'resources',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_resources_kv_store ON resources;
CREATE TRIGGER trg_resources_kv_store
AFTER INSERT OR UPDATE OR DELETE ON resources
FOR EACH ROW EXECUTE FUNCTION fn_resources_kv_store_upsert();

-- ======================================================================
-- SCHEMAS (Model: Schema)
-- ======================================================================

CREATE TABLE IF NOT EXISTS schemas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256) NOT NULL,
    content TEXT,
    spec JSONB NOT NULL,
    category VARCHAR(256),
    provider_configs JSONB DEFAULT '{}'::jsonb,
    embedding_fields TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_schemas_tenant ON schemas (tenant_id);
CREATE INDEX idx_schemas_user ON schemas (user_id);
CREATE INDEX idx_schemas_graph_edges ON schemas USING GIN (graph_edges);
CREATE INDEX idx_schemas_metadata ON schemas USING GIN (metadata);
CREATE INDEX idx_schemas_tags ON schemas USING GIN (tags);

-- Embeddings for schemas
CREATE TABLE IF NOT EXISTS embeddings_schemas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES schemas(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_schemas_entity ON embeddings_schemas (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_schemas_field_provider ON embeddings_schemas (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_schemas_vector_hnsw ON embeddings_schemas
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for schemas
-- Trigger function to maintain KV_STORE for schemas
CREATE OR REPLACE FUNCTION fn_schemas_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.id::VARCHAR,
            'schemas',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_schemas_kv_store ON schemas;
CREATE TRIGGER trg_schemas_kv_store
AFTER INSERT OR UPDATE OR DELETE ON schemas
FOR EACH ROW EXECUTE FUNCTION fn_schemas_kv_store_upsert();

-- ======================================================================
-- SESSIONS (Model: Session)
-- ======================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256) NOT NULL,
    mode TEXT,
    description TEXT,
    original_trace_id VARCHAR(256),
    settings_overrides JSONB,
    prompt TEXT,
    agent_schema_uri VARCHAR(256),
    message_count INTEGER,
    total_tokens INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_sessions_tenant ON sessions (tenant_id);
CREATE INDEX idx_sessions_user ON sessions (user_id);
CREATE INDEX idx_sessions_graph_edges ON sessions USING GIN (graph_edges);
CREATE INDEX idx_sessions_metadata ON sessions USING GIN (metadata);
CREATE INDEX idx_sessions_tags ON sessions USING GIN (tags);

-- Embeddings for sessions
CREATE TABLE IF NOT EXISTS embeddings_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_sessions_entity ON embeddings_sessions (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_sessions_field_provider ON embeddings_sessions (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_sessions_vector_hnsw ON embeddings_sessions
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for sessions
-- Trigger function to maintain KV_STORE for sessions
CREATE OR REPLACE FUNCTION fn_sessions_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.name::VARCHAR,
            'sessions',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_sessions_kv_store ON sessions;
CREATE TRIGGER trg_sessions_kv_store
AFTER INSERT OR UPDATE OR DELETE ON sessions
FOR EACH ROW EXECUTE FUNCTION fn_sessions_kv_store_upsert();

-- ======================================================================
-- SHARED_SESSIONS (Model: SharedSession)
-- ======================================================================

CREATE TABLE IF NOT EXISTS shared_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    session_id VARCHAR(256) NOT NULL,
    owner_user_id VARCHAR(256) NOT NULL,
    shared_with_user_id VARCHAR(256) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_shared_sessions_tenant ON shared_sessions (tenant_id);
CREATE INDEX idx_shared_sessions_user ON shared_sessions (user_id);
CREATE INDEX idx_shared_sessions_graph_edges ON shared_sessions USING GIN (graph_edges);
CREATE INDEX idx_shared_sessions_metadata ON shared_sessions USING GIN (metadata);
CREATE INDEX idx_shared_sessions_tags ON shared_sessions USING GIN (tags);

-- KV_STORE trigger for shared_sessions
-- Trigger function to maintain KV_STORE for shared_sessions
CREATE OR REPLACE FUNCTION fn_shared_sessions_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.id::VARCHAR,
            'shared_sessions',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_shared_sessions_kv_store ON shared_sessions;
CREATE TRIGGER trg_shared_sessions_kv_store
AFTER INSERT OR UPDATE OR DELETE ON shared_sessions
FOR EACH ROW EXECUTE FUNCTION fn_shared_sessions_kv_store_upsert();

-- ======================================================================
-- USERS (Model: User)
-- ======================================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(256),
    name VARCHAR(256) NOT NULL,
    email VARCHAR(256),
    role VARCHAR(256),
    tier TEXT,
    anonymous_ids TEXT[] DEFAULT ARRAY[]::TEXT[],
    sec_policy JSONB DEFAULT '{}'::jsonb,
    summary TEXT,
    interests TEXT[] DEFAULT ARRAY[]::TEXT[],
    preferred_topics TEXT[] DEFAULT ARRAY[]::TEXT[],
    activity_level VARCHAR(256),
    last_active_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    graph_edges JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    tags TEXT[] DEFAULT ARRAY[]::TEXT[]
);

CREATE INDEX idx_users_tenant ON users (tenant_id);
CREATE INDEX idx_users_user ON users (user_id);
CREATE INDEX idx_users_graph_edges ON users USING GIN (graph_edges);
CREATE INDEX idx_users_metadata ON users USING GIN (metadata);
CREATE INDEX idx_users_tags ON users USING GIN (tags);

-- Embeddings for users
CREATE TABLE IF NOT EXISTS embeddings_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'openai',
    model VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
    embedding vector(1536) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Unique: one embedding per entity per field per provider
    UNIQUE (entity_id, field_name, provider)
);

-- Index for entity lookup (get all embeddings for entity)
CREATE INDEX idx_embeddings_users_entity ON embeddings_users (entity_id);

-- Index for field + provider lookup
CREATE INDEX idx_embeddings_users_field_provider ON embeddings_users (field_name, provider);

-- HNSW index for vector similarity search (created in background)
-- Note: This will be created by background thread after data load
-- CREATE INDEX idx_embeddings_users_vector_hnsw ON embeddings_users
-- USING hnsw (embedding vector_cosine_ops);

-- KV_STORE trigger for users
-- Trigger function to maintain KV_STORE for users
CREATE OR REPLACE FUNCTION fn_users_kv_store_upsert()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        -- Remove from KV_STORE on delete
        DELETE FROM kv_store
        WHERE entity_id = OLD.id;
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        -- Upsert to KV_STORE (O(1) lookup by entity_key)
        INSERT INTO kv_store (
            entity_key,
            entity_type,
            entity_id,
            tenant_id,
            user_id,
            metadata,
            graph_edges,
            updated_at
        ) VALUES (
            NEW.name::VARCHAR,
            'users',
            NEW.id,
            NEW.tenant_id,
            NEW.user_id,
            NEW.metadata,
            COALESCE(NEW.graph_edges, '[]'::jsonb),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (tenant_id, entity_key)
        DO UPDATE SET
            entity_id = EXCLUDED.entity_id,
            user_id = EXCLUDED.user_id,
            metadata = EXCLUDED.metadata,
            graph_edges = EXCLUDED.graph_edges,
            updated_at = CURRENT_TIMESTAMP;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_users_kv_store ON users;
CREATE TRIGGER trg_users_kv_store
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION fn_users_kv_store_upsert();

-- ============================================================================
-- SCHEMA TABLE ENTRIES
-- Every entity table gets a schemas entry for agent-like access
-- ============================================================================

-- Schema entry for Feedback (feedbacks)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'ae554853-e743-5d73-a2db-1ce20e7089fe'::uuid,
    'system',
    'Feedback',
    '# Feedback


    User feedback on a message or session.

    Captures structured feedback including:
    - Rating (1-5 scale or thumbs up/down)
    - Categories (predefined or custom)
    - Free-text comment
    - Trace reference for OTEL/Phoenix integration

    The feedback can be attached to:
    - A specific message (message_id set)
    - An entire session (session_id set, message_id null)
    

## Overview

The `Feedback` entity is stored in the `feedbacks` table. Each record is uniquely
identified by its `id` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by id (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM feedbacks LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM feedbacks WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `feedbacks` |
| Entity Key | `id` |
| Embedding Fields | None |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `session_id`
- **Type**: `<class ''str''>`
- **Required**
- Session ID this feedback relates to

### `message_id`
- **Type**: `str | None`
- **Optional**
- Specific message ID (null for session-level feedback)

### `rating`
- **Type**: `int | None`
- **Optional**
- Rating: -1 (thumbs down), 1 (thumbs up), or 1-5 scale

### `categories`
- **Type**: `list[str]`
- **Optional**
- Selected feedback categories (from FeedbackCategory or custom)

### `comment`
- **Type**: `str | None`
- **Optional**
- Optional free-text feedback comment

### `trace_id`
- **Type**: `str | None`
- **Optional**
- OTEL trace ID for linking to observability

### `span_id`
- **Type**: `str | None`
- **Optional**
- OTEL span ID for specific span feedback

### `phoenix_synced`
- **Type**: `<class ''bool''>`
- **Optional**
- Whether feedback has been synced to Phoenix as annotation

### `phoenix_annotation_id`
- **Type**: `str | None`
- **Optional**
- Phoenix annotation ID after sync

### `annotator_kind`
- **Type**: `<class ''str''>`
- **Optional**
- Annotator type: HUMAN, LLM, CODE

',
    '{"type": "object", "description": "\n    User feedback on a message or session.\n\n    Captures structured feedback including:\n    - Rating (1-5 scale or thumbs up/down)\n    - Categories (predefined or custom)\n    - Free-text comment\n    - Trace reference for OTEL/Phoenix integration\n\n    The feedback can be attached to:\n    - A specific message (message_id set)\n    - An entire session (session_id set, message_id null)\n    \n\nThis agent can search the `feedbacks` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "session_id": {"description": "Session ID this feedback relates to", "title": "Session Id", "type": "string"}, "message_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Specific message ID (null for session-level feedback)", "title": "Message Id"}, "rating": {"anyOf": [{"maximum": 5, "minimum": -1, "type": "integer"}, {"type": "null"}], "default": null, "description": "Rating: -1 (thumbs down), 1 (thumbs up), or 1-5 scale", "title": "Rating"}, "categories": {"description": "Selected feedback categories (from FeedbackCategory or custom)", "items": {"type": "string"}, "title": "Categories", "type": "array"}, "comment": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Optional free-text feedback comment", "title": "Comment"}, "trace_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "OTEL trace ID for linking to observability", "title": "Trace Id"}, "span_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "OTEL span ID for specific span feedback", "title": "Span Id"}, "phoenix_synced": {"default": false, "description": "Whether feedback has been synced to Phoenix as annotation", "title": "Phoenix Synced", "type": "boolean"}, "phoenix_annotation_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Phoenix annotation ID after sync", "title": "Phoenix Annotation Id"}, "annotator_kind": {"default": "HUMAN", "description": "Annotator type: HUMAN, LLM, CODE", "title": "Annotator Kind", "type": "string"}}, "required": ["session_id"], "json_schema_extra": {"table_name": "feedbacks", "entity_key_field": "id", "embedding_fields": [], "fully_qualified_name": "rem.models.entities.feedback.Feedback", "tools": ["search_rem"], "default_search_table": "feedbacks", "has_embeddings": false}}'::jsonb,
    'entity',
    '{"table_name": "feedbacks", "entity_key_field": "id", "embedding_fields": [], "fqn": "rem.models.entities.feedback.Feedback"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for File (files)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'c3b3ef33-59d4-57a1-81a3-cc6adc45b194'::uuid,
    'system',
    'File',
    '# File


    File metadata and tracking.

    Represents files uploaded to or referenced by the REM system,
    tracking their metadata and processing status. Tenant isolation
    is provided via CoreModel.tenant_id field.
    

## Overview

The `File` entity is stored in the `files` table. Each record is uniquely
identified by its `id` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by id (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM files LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM files WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `files` |
| Entity Key | `id` |
| Embedding Fields | `content` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `<class ''str''>`
- **Required**
- File name

### `uri`
- **Type**: `<class ''str''>`
- **Required**
- File storage URI (S3, local path, etc.)

### `content`
- **Type**: `typing.Optional[str]`
- **Optional**
- Extracted text content (if applicable)

### `timestamp`
- **Type**: `typing.Optional[str]`
- **Optional**
- File creation/modification timestamp

### `size_bytes`
- **Type**: `typing.Optional[int]`
- **Optional**
- File size in bytes

### `mime_type`
- **Type**: `typing.Optional[str]`
- **Optional**
- File MIME type

### `processing_status`
- **Type**: `typing.Optional[str]`
- **Optional**
- File processing status (pending, processing, completed, failed)

',
    '{"type": "object", "description": "\n    File metadata and tracking.\n\n    Represents files uploaded to or referenced by the REM system,\n    tracking their metadata and processing status. Tenant isolation\n    is provided via CoreModel.tenant_id field.\n    \n\nThis agent can search the `files` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"description": "File name", "title": "Name", "type": "string"}, "uri": {"description": "File storage URI (S3, local path, etc.)", "title": "Uri", "type": "string"}, "content": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Extracted text content (if applicable)", "title": "Content"}, "timestamp": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "File creation/modification timestamp", "title": "Timestamp"}, "size_bytes": {"anyOf": [{"type": "integer"}, {"type": "null"}], "default": null, "description": "File size in bytes", "title": "Size Bytes"}, "mime_type": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "File MIME type", "title": "Mime Type"}, "processing_status": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": "pending", "description": "File processing status (pending, processing, completed, failed)", "title": "Processing Status"}}, "required": ["name", "uri"], "json_schema_extra": {"table_name": "files", "entity_key_field": "id", "embedding_fields": ["content"], "fully_qualified_name": "rem.models.entities.file.File", "tools": ["search_rem"], "default_search_table": "files", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "files", "entity_key_field": "id", "embedding_fields": ["content"], "fqn": "rem.models.entities.file.File"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for ImageResource (image_resources)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'ab4bc90c-2cda-55b2-bd4b-e78e19f7d4a7'::uuid,
    'system',
    'ImageResource',
    '# ImageResource


    Image-specific resource with CLIP embeddings.

    Stored in separate `image_resources` table with CLIP embeddings
    instead of text embeddings. This enables:
    - Multimodal search (text-to-image, image-to-image)
    - Proper dimensionality (512/768 for CLIP vs 1536 for text)
    - Cost tracking (CLIP tokens separate from text tokens)

    Embedding Strategy:
    - Default (when JINA_API_KEY set): Jina CLIP API (jina-clip-v2)
    - Future: Self-hosted OpenCLIP models via KEDA-scaled pods
    - Fallback: No embeddings (images searchable by metadata only)

    Vision LLM Strategy (tier/sampling gated):
    - Gold tier: Always get vision descriptions
    - Silver/Free: Probabilistic sampling (IMAGE_VLLM_SAMPLE_RATE)
    - Fallback: Basic metadata only

    Tenant isolation provided via CoreModel.tenant_id field.
    

## Overview

The `ImageResource` entity is stored in the `image_resources` table. Each record is uniquely
identified by its `name` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by name (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM image_resources LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM image_resources WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `image_resources` |
| Entity Key | `name` |
| Embedding Fields | `content` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `typing.Optional[str]`
- **Optional**
- Human-readable resource name (used as graph label). Auto-generated from uri+ordinal if not provided.

### `uri`
- **Type**: `typing.Optional[str]`
- **Optional**
- Content URI or identifier (file path, URL, etc.)

### `ordinal`
- **Type**: `<class ''int''>`
- **Optional**
- Chunk ordinal for splitting large documents (0 for single-chunk resources)

### `content`
- **Type**: `<class ''str''>`
- **Optional**
- Resource content text

### `timestamp`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Resource timestamp (content creation/publication time)

### `category`
- **Type**: `typing.Optional[str]`
- **Optional**
- Resource category (document, conversation, artifact, etc.)

### `related_entities`
- **Type**: `list[dict]`
- **Optional**
- Extracted entities (people, projects, concepts) with metadata

### `image_width`
- **Type**: `typing.Optional[int]`
- **Optional**
- Image width in pixels

### `image_height`
- **Type**: `typing.Optional[int]`
- **Optional**
- Image height in pixels

### `image_format`
- **Type**: `typing.Optional[str]`
- **Optional**
- Image format (PNG, JPEG, GIF, WebP)

### `vision_description`
- **Type**: `typing.Optional[str]`
- **Optional**
- Vision LLM generated description (markdown, only for gold tier or sampled images)

### `vision_provider`
- **Type**: `typing.Optional[str]`
- **Optional**
- Vision provider used (anthropic, gemini, openai)

### `vision_model`
- **Type**: `typing.Optional[str]`
- **Optional**
- Vision model used for description

### `clip_embedding`
- **Type**: `typing.Optional[list[float]]`
- **Optional**
- CLIP embedding vector (512 or 768 dimensions, from Jina AI or self-hosted)

### `clip_dimensions`
- **Type**: `typing.Optional[int]`
- **Optional**
- CLIP embedding dimensionality (512 for jina-clip-v2, 768 for jina-clip-v1)

',
    '{"type": "object", "description": "\n    Image-specific resource with CLIP embeddings.\n\n    Stored in separate `image_resources` table with CLIP embeddings\n    instead of text embeddings. This enables:\n    - Multimodal search (text-to-image, image-to-image)\n    - Proper dimensionality (512/768 for CLIP vs 1536 for text)\n    - Cost tracking (CLIP tokens separate from text tokens)\n\n    Embedding Strategy:\n    - Default (when JINA_API_KEY set): Jina CLIP API (jina-clip-v2)\n    - Future: Self-hosted OpenCLIP models via KEDA-scaled pods\n    - Fallback: No embeddings (images searchable by metadata only)\n\n    Vision LLM Strategy (tier/sampling gated):\n    - Gold tier: Always get vision descriptions\n    - Silver/Free: Probabilistic sampling (IMAGE_VLLM_SAMPLE_RATE)\n    - Fallback: Basic metadata only\n\n    Tenant isolation provided via CoreModel.tenant_id field.\n    \n\nThis agent can search the `image_resources` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Human-readable resource name (used as graph label). Auto-generated from uri+ordinal if not provided.", "entity_key": true, "title": "Name"}, "uri": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Content URI or identifier (file path, URL, etc.)", "title": "Uri"}, "ordinal": {"composite_key": true, "default": 0, "description": "Chunk ordinal for splitting large documents (0 for single-chunk resources)", "title": "Ordinal", "type": "integer"}, "content": {"default": "", "description": "Resource content text", "title": "Content", "type": "string"}, "timestamp": {"description": "Resource timestamp (content creation/publication time)", "format": "date-time", "title": "Timestamp", "type": "string"}, "category": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Resource category (document, conversation, artifact, etc.)", "title": "Category"}, "related_entities": {"description": "Extracted entities (people, projects, concepts) with metadata", "items": {"additionalProperties": true, "type": "object"}, "title": "Related Entities", "type": "array"}, "image_width": {"anyOf": [{"type": "integer"}, {"type": "null"}], "default": null, "description": "Image width in pixels", "title": "Image Width"}, "image_height": {"anyOf": [{"type": "integer"}, {"type": "null"}], "default": null, "description": "Image height in pixels", "title": "Image Height"}, "image_format": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Image format (PNG, JPEG, GIF, WebP)", "title": "Image Format"}, "vision_description": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Vision LLM generated description (markdown, only for gold tier or sampled images)", "title": "Vision Description"}, "vision_provider": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Vision provider used (anthropic, gemini, openai)", "title": "Vision Provider"}, "vision_model": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Vision model used for description", "title": "Vision Model"}, "clip_embedding": {"anyOf": [{"items": {"type": "number"}, "type": "array"}, {"type": "null"}], "default": null, "description": "CLIP embedding vector (512 or 768 dimensions, from Jina AI or self-hosted)", "title": "Clip Embedding"}, "clip_dimensions": {"anyOf": [{"type": "integer"}, {"type": "null"}], "default": null, "description": "CLIP embedding dimensionality (512 for jina-clip-v2, 768 for jina-clip-v1)", "title": "Clip Dimensions"}}, "required": [], "json_schema_extra": {"table_name": "image_resources", "entity_key_field": "name", "embedding_fields": ["content"], "fully_qualified_name": "rem.models.entities.image_resource.ImageResource", "tools": ["search_rem"], "default_search_table": "image_resources", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "image_resources", "entity_key_field": "name", "embedding_fields": ["content"], "fqn": "rem.models.entities.image_resource.ImageResource"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for Message (messages)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'be36f9da-6df4-51ba-bb41-bf51246ecec1'::uuid,
    'system',
    'Message',
    '# Message


    Communication content unit.

    Represents individual messages in conversations, chats, or other
    communication contexts. Tenant isolation is provided via CoreModel.tenant_id field.

    Trace fields (trace_id, span_id) enable integration with OTEL/Phoenix
    for observability and feedback annotation.
    

## Overview

The `Message` entity is stored in the `messages` table. Each record is uniquely
identified by its `id` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by id (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM messages LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM messages WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `messages` |
| Entity Key | `id` |
| Embedding Fields | `content` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `content`
- **Type**: `<class ''str''>`
- **Required**
- Message content text

### `message_type`
- **Type**: `str | None`
- **Optional**
- Message type e.g. role: ''user'', ''assistant'', ''system'', ''tool''

### `session_id`
- **Type**: `str | None`
- **Optional**
- Session identifier for tracking message context

### `prompt`
- **Type**: `str | None`
- **Optional**
- Custom prompt used for this message (if overridden from default)

### `model`
- **Type**: `str | None`
- **Optional**
- Model used for generating this message (provider:model format)

### `token_count`
- **Type**: `int | None`
- **Optional**
- Token count for this message

### `trace_id`
- **Type**: `str | None`
- **Optional**
- OTEL trace ID for observability integration

### `span_id`
- **Type**: `str | None`
- **Optional**
- OTEL span ID for specific span reference

',
    '{"type": "object", "description": "\n    Communication content unit.\n\n    Represents individual messages in conversations, chats, or other\n    communication contexts. Tenant isolation is provided via CoreModel.tenant_id field.\n\n    Trace fields (trace_id, span_id) enable integration with OTEL/Phoenix\n    for observability and feedback annotation.\n    \n\nThis agent can search the `messages` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "content": {"description": "Message content text", "title": "Content", "type": "string"}, "message_type": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Message type e.g. role: ''user'', ''assistant'', ''system'', ''tool''", "title": "Message Type"}, "session_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Session identifier for tracking message context", "title": "Session Id"}, "prompt": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Custom prompt used for this message (if overridden from default)", "title": "Prompt"}, "model": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Model used for generating this message (provider:model format)", "title": "Model"}, "token_count": {"anyOf": [{"type": "integer"}, {"type": "null"}], "default": null, "description": "Token count for this message", "title": "Token Count"}, "trace_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "OTEL trace ID for observability integration", "title": "Trace Id"}, "span_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "OTEL span ID for specific span reference", "title": "Span Id"}}, "required": ["content"], "json_schema_extra": {"table_name": "messages", "entity_key_field": "id", "embedding_fields": ["content"], "fully_qualified_name": "rem.models.entities.message.Message", "tools": ["search_rem"], "default_search_table": "messages", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "messages", "entity_key_field": "id", "embedding_fields": ["content"], "fqn": "rem.models.entities.message.Message"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for Moment (moments)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'a08f0a8c-5bab-5bf5-9760-0e67bc69bd74'::uuid,
    'system',
    'Moment',
    '# Moment


    Temporal narrative extracted from resources.

    Moments provide temporal structure and context for the REM graph,
    enabling time-based queries and understanding of when events occurred.
    Tenant isolation is provided via CoreModel.tenant_id field.
    

## Overview

The `Moment` entity is stored in the `moments` table. Each record is uniquely
identified by its `name` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by name (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on summary (e.g., `SEARCH "concept" FROM moments LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM moments WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `moments` |
| Entity Key | `name` |
| Embedding Fields | `summary` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `typing.Optional[str]`
- **Optional**
- Human-readable moment name (used as graph label). Auto-generated from starts_timestamp+moment_type if not provided.

### `moment_type`
- **Type**: `typing.Optional[str]`
- **Optional**
- Moment classification (meeting, coding-session, conversation, etc.)

### `category`
- **Type**: `typing.Optional[str]`
- **Optional**
- Moment category for grouping and filtering

### `starts_timestamp`
- **Type**: `<class ''datetime.datetime''>`
- **Required**
- Moment start time

### `ends_timestamp`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Moment end time

### `present_persons`
- **Type**: `list[rem.models.entities.moment.Person]`
- **Optional**
- People present in the moment

### `emotion_tags`
- **Type**: `list[str]`
- **Optional**
- Emotion/sentiment tags (happy, frustrated, focused, etc.)

### `topic_tags`
- **Type**: `list[str]`
- **Optional**
- Topic/concept tags (project names, technologies, etc.)

### `summary`
- **Type**: `typing.Optional[str]`
- **Optional**
- Natural language summary of the moment

### `source_resource_ids`
- **Type**: `list[str]`
- **Optional**
- Resource IDs used to construct this moment

',
    '{"type": "object", "description": "\n    Temporal narrative extracted from resources.\n\n    Moments provide temporal structure and context for the REM graph,\n    enabling time-based queries and understanding of when events occurred.\n    Tenant isolation is provided via CoreModel.tenant_id field.\n    \n\nThis agent can search the `moments` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Human-readable moment name (used as graph label). Auto-generated from starts_timestamp+moment_type if not provided.", "entity_key": true, "title": "Name"}, "moment_type": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Moment classification (meeting, coding-session, conversation, etc.)", "title": "Moment Type"}, "category": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Moment category for grouping and filtering", "title": "Category"}, "starts_timestamp": {"description": "Moment start time", "format": "date-time", "title": "Starts Timestamp", "type": "string"}, "ends_timestamp": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Moment end time", "title": "Ends Timestamp"}, "present_persons": {"description": "People present in the moment", "items": {"$ref": "#/$defs/Person"}, "title": "Present Persons", "type": "array"}, "emotion_tags": {"description": "Emotion/sentiment tags (happy, frustrated, focused, etc.)", "items": {"type": "string"}, "title": "Emotion Tags", "type": "array"}, "topic_tags": {"description": "Topic/concept tags (project names, technologies, etc.)", "items": {"type": "string"}, "title": "Topic Tags", "type": "array"}, "summary": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Natural language summary of the moment", "title": "Summary"}, "source_resource_ids": {"description": "Resource IDs used to construct this moment", "items": {"type": "string"}, "title": "Source Resource Ids", "type": "array"}}, "required": ["starts_timestamp"], "json_schema_extra": {"table_name": "moments", "entity_key_field": "name", "embedding_fields": ["summary"], "fully_qualified_name": "rem.models.entities.moment.Moment", "tools": ["search_rem"], "default_search_table": "moments", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "moments", "entity_key_field": "name", "embedding_fields": ["summary"], "fqn": "rem.models.entities.moment.Moment"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for Ontology (ontologies)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'a702ed74-8988-534a-9917-2977349777c1'::uuid,
    'system',
    'Ontology',
    '# Ontology

Domain-specific knowledge extracted from files using custom agents.

    Attributes:
        name: Human-readable label for this ontology instance
        file_id: Foreign key to File entity that was processed
        agent_schema_id: Foreign key to Schema entity that performed extraction
        provider_name: LLM provider used for extraction (e.g., "anthropic", "openai")
        model_name: Specific model used (e.g., "claude-sonnet-4-5")
        extracted_data: Structured data extracted by agent (arbitrary JSON)
        confidence_score: Optional confidence score from extraction (0.0-1.0)
        extraction_timestamp: When extraction was performed
        embedding_text: Text used for generating embedding (derived from extracted_data)

    Inherited from CoreModel:
        id: UUID or string identifier
        created_at: Entity creation timestamp
        updated_at: Last update timestamp
        deleted_at: Soft deletion timestamp
        tenant_id: Multi-tenancy isolation
        user_id: Ownership
        graph_edges: Relationships to other entities
        metadata: Flexible metadata storage
        tags: Classification tags
        column: Database schema metadata

    Example Usage:
        # CV extraction
        cv_ontology = Ontology(
            name="john-doe-cv-2024",
            file_id="file-uuid-123",
            agent_schema_id="cv-parser-v1",
            provider_name="anthropic",
            model_name="claude-sonnet-4-5-20250929",
            extracted_data={
                "candidate_name": "John Doe",
                "email": "john@example.com",
                "skills": ["Python", "PostgreSQL", "Kubernetes"],
                "experience": [
                    {
                        "company": "TechCorp",
                        "role": "Senior Engineer",
                        "years": 3,
                        "achievements": ["Led migration to k8s", "Reduced costs 40%"]
                    }
                ],
                "education": [
                    {"degree": "BS Computer Science", "institution": "MIT", "year": 2018}
                ]
            },
            confidence_score=0.95,
            tags=["cv", "engineering", "senior-level"]
        )

        # Contract extraction
        contract_ontology = Ontology(
            name="acme-supplier-agreement-2024",
            file_id="file-uuid-456",
            agent_schema_id="contract-parser-v2",
            provider_name="openai",
            model_name="gpt-4o",
            extracted_data={
                "contract_type": "supplier_agreement",
                "parties": [
                    {"name": "ACME Corp", "role": "buyer"},
                    {"name": "SupplyChain Inc", "role": "supplier"}
                ],
                "effective_date": "2024-01-01",
                "termination_date": "2026-12-31",
                "payment_terms": {
                    "amount": 500000,
                    "currency": "USD",
                    "frequency": "quarterly"
                },
                "key_obligations": [
                    "Supplier must deliver within 30 days",
                    "Buyer must pay within 60 days of invoice"
                ]
            },
            confidence_score=0.92,
            tags=["contract", "supplier", "procurement"]
        )
    

## Overview

The `Ontology` entity is stored in the `ontologies` table. Each record is uniquely
identified by its `id` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by id (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM ontologies LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM ontologies WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `ontologies` |
| Entity Key | `id` |
| Embedding Fields | None |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `<class ''str''>`
- **Required**

### `file_id`
- **Type**: `uuid.UUID | str`
- **Required**

### `agent_schema_id`
- **Type**: `<class ''str''>`
- **Required**

### `provider_name`
- **Type**: `<class ''str''>`
- **Required**

### `model_name`
- **Type**: `<class ''str''>`
- **Required**

### `extracted_data`
- **Type**: `dict[str, typing.Any]`
- **Required**

### `confidence_score`
- **Type**: `typing.Optional[float]`
- **Optional**

### `extraction_timestamp`
- **Type**: `typing.Optional[str]`
- **Optional**

### `embedding_text`
- **Type**: `typing.Optional[str]`
- **Optional**

',
    '{"type": "object", "description": "Domain-specific knowledge extracted from files using custom agents.\n\n    Attributes:\n        name: Human-readable label for this ontology instance\n        file_id: Foreign key to File entity that was processed\n        agent_schema_id: Foreign key to Schema entity that performed extraction\n        provider_name: LLM provider used for extraction (e.g., \"anthropic\", \"openai\")\n        model_name: Specific model used (e.g., \"claude-sonnet-4-5\")\n        extracted_data: Structured data extracted by agent (arbitrary JSON)\n        confidence_score: Optional confidence score from extraction (0.0-1.0)\n        extraction_timestamp: When extraction was performed\n        embedding_text: Text used for generating embedding (derived from extracted_data)\n\n    Inherited from CoreModel:\n        id: UUID or string identifier\n        created_at: Entity creation timestamp\n        updated_at: Last update timestamp\n        deleted_at: Soft deletion timestamp\n        tenant_id: Multi-tenancy isolation\n        user_id: Ownership\n        graph_edges: Relationships to other entities\n        metadata: Flexible metadata storage\n        tags: Classification tags\n        column: Database schema metadata\n\n    Example Usage:\n        # CV extraction\n        cv_ontology = Ontology(\n            name=\"john-doe-cv-2024\",\n            file_id=\"file-uuid-123\",\n            agent_schema_id=\"cv-parser-v1\",\n            provider_name=\"anthropic\",\n            model_name=\"claude-sonnet-4-5-20250929\",\n            extracted_data={\n                \"candidate_name\": \"John Doe\",\n                \"email\": \"john@example.com\",\n                \"skills\": [\"Python\", \"PostgreSQL\", \"Kubernetes\"],\n                \"experience\": [\n                    {\n                        \"company\": \"TechCorp\",\n                        \"role\": \"Senior Engineer\",\n                        \"years\": 3,\n                        \"achievements\": [\"Led migration to k8s\", \"Reduced costs 40%\"]\n                    }\n                ],\n                \"education\": [\n                    {\"degree\": \"BS Computer Science\", \"institution\": \"MIT\", \"year\": 2018}\n                ]\n            },\n            confidence_score=0.95,\n            tags=[\"cv\", \"engineering\", \"senior-level\"]\n        )\n\n        # Contract extraction\n        contract_ontology = Ontology(\n            name=\"acme-supplier-agreement-2024\",\n            file_id=\"file-uuid-456\",\n            agent_schema_id=\"contract-parser-v2\",\n            provider_name=\"openai\",\n            model_name=\"gpt-4o\",\n            extracted_data={\n                \"contract_type\": \"supplier_agreement\",\n                \"parties\": [\n                    {\"name\": \"ACME Corp\", \"role\": \"buyer\"},\n                    {\"name\": \"SupplyChain Inc\", \"role\": \"supplier\"}\n                ],\n                \"effective_date\": \"2024-01-01\",\n                \"termination_date\": \"2026-12-31\",\n                \"payment_terms\": {\n                    \"amount\": 500000,\n                    \"currency\": \"USD\",\n                    \"frequency\": \"quarterly\"\n                },\n                \"key_obligations\": [\n                    \"Supplier must deliver within 30 days\",\n                    \"Buyer must pay within 60 days of invoice\"\n                ]\n            },\n            confidence_score=0.92,\n            tags=[\"contract\", \"supplier\", \"procurement\"]\n        )\n    \n\nThis agent can search the `ontologies` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"title": "Name", "type": "string"}, "file_id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}], "title": "File Id"}, "agent_schema_id": {"title": "Agent Schema Id", "type": "string"}, "provider_name": {"title": "Provider Name", "type": "string"}, "model_name": {"title": "Model Name", "type": "string"}, "extracted_data": {"additionalProperties": true, "title": "Extracted Data", "type": "object"}, "confidence_score": {"anyOf": [{"type": "number"}, {"type": "null"}], "default": null, "title": "Confidence Score"}, "extraction_timestamp": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "title": "Extraction Timestamp"}, "embedding_text": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "title": "Embedding Text"}}, "required": ["name", "file_id", "agent_schema_id", "provider_name", "model_name", "extracted_data"], "json_schema_extra": {"table_name": "ontologies", "entity_key_field": "id", "embedding_fields": [], "fully_qualified_name": "rem.models.entities.ontology.Ontology", "tools": ["search_rem"], "default_search_table": "ontologies", "has_embeddings": false}}'::jsonb,
    'entity',
    '{"table_name": "ontologies", "entity_key_field": "id", "embedding_fields": [], "fqn": "rem.models.entities.ontology.Ontology"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for OntologyConfig (ontology_configs)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    '9a7e50d0-ef3a-5641-9ff4-b2be5a77053b'::uuid,
    'system',
    'OntologyConfig',
    '# OntologyConfig

User configuration for automatic ontology extraction.

    Attributes:
        name: Human-readable config name
        agent_schema_id: Foreign key to Schema entity to use for extraction
        description: Purpose and scope of this config

        # File matching rules (ANY matching rule triggers extraction)
        mime_type_pattern: Regex pattern for file MIME types (e.g., "application/pdf")
        uri_pattern: Regex pattern for file URIs (e.g., "s3://bucket/resumes/.*")
        tag_filter: List of tags (file must have ALL tags to match)

        # Execution control
        priority: Execution order (higher = earlier, default 100)
        enabled: Whether this config is active (default True)

        # LLM provider configuration
        provider_name: Optional LLM provider override (defaults to settings)
        model_name: Optional model override (defaults to settings)

    Inherited from CoreModel:
        id, created_at, updated_at, deleted_at, tenant_id, user_id,
        graph_edges, metadata, tags, column

    Example Usage:
        # CV extraction for recruitment
        cv_config = OntologyConfig(
            name="recruitment-cv-parser",
            agent_schema_id="cv-parser-v1",
            description="Extract candidate information from resumes",
            mime_type_pattern="application/pdf",
            uri_pattern=".*/resumes/.*",
            tag_filter=["cv", "candidate"],
            priority=100,
            enabled=True,
            tenant_id="acme-corp",
            tags=["recruitment", "hr"]
        )

        # Contract analysis for legal team
        contract_config = OntologyConfig(
            name="legal-contract-analyzer",
            agent_schema_id="contract-parser-v2",
            description="Extract key terms from supplier contracts",
            mime_type_pattern="application/(pdf|msword|vnd.openxmlformats.*)",
            tag_filter=["legal", "contract"],
            priority=200,  # Higher priority = runs first
            enabled=True,
            provider_name="openai",  # Override default provider
            model_name="gpt-4o",
            tenant_id="acme-corp",
            tags=["legal", "procurement"]
        )

        # Medical records for healthcare
        medical_config = OntologyConfig(
            name="medical-records-extractor",
            agent_schema_id="medical-parser-v1",
            description="Extract diagnoses and treatments from medical records",
            mime_type_pattern="application/pdf",
            tag_filter=["medical", "patient-record"],
            priority=50,
            enabled=True,
            tenant_id="healthsystem",
            tags=["medical", "hipaa-compliant"]
        )
    

## Overview

The `OntologyConfig` entity is stored in the `ontology_configs` table. Each record is uniquely
identified by its `id` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by id (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on description (e.g., `SEARCH "concept" FROM ontology_configs LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM ontology_configs WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `ontology_configs` |
| Entity Key | `id` |
| Embedding Fields | `description` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `<class ''str''>`
- **Required**

### `agent_schema_id`
- **Type**: `<class ''str''>`
- **Required**

### `description`
- **Type**: `typing.Optional[str]`
- **Optional**

### `mime_type_pattern`
- **Type**: `typing.Optional[str]`
- **Optional**

### `uri_pattern`
- **Type**: `typing.Optional[str]`
- **Optional**

### `tag_filter`
- **Type**: `list[str]`
- **Optional**

### `priority`
- **Type**: `<class ''int''>`
- **Optional**

### `enabled`
- **Type**: `<class ''bool''>`
- **Optional**

### `provider_name`
- **Type**: `typing.Optional[str]`
- **Optional**

### `model_name`
- **Type**: `typing.Optional[str]`
- **Optional**

',
    '{"type": "object", "description": "User configuration for automatic ontology extraction.\n\n    Attributes:\n        name: Human-readable config name\n        agent_schema_id: Foreign key to Schema entity to use for extraction\n        description: Purpose and scope of this config\n\n        # File matching rules (ANY matching rule triggers extraction)\n        mime_type_pattern: Regex pattern for file MIME types (e.g., \"application/pdf\")\n        uri_pattern: Regex pattern for file URIs (e.g., \"s3://bucket/resumes/.*\")\n        tag_filter: List of tags (file must have ALL tags to match)\n\n        # Execution control\n        priority: Execution order (higher = earlier, default 100)\n        enabled: Whether this config is active (default True)\n\n        # LLM provider configuration\n        provider_name: Optional LLM provider override (defaults to settings)\n        model_name: Optional model override (defaults to settings)\n\n    Inherited from CoreModel:\n        id, created_at, updated_at, deleted_at, tenant_id, user_id,\n        graph_edges, metadata, tags, column\n\n    Example Usage:\n        # CV extraction for recruitment\n        cv_config = OntologyConfig(\n            name=\"recruitment-cv-parser\",\n            agent_schema_id=\"cv-parser-v1\",\n            description=\"Extract candidate information from resumes\",\n            mime_type_pattern=\"application/pdf\",\n            uri_pattern=\".*/resumes/.*\",\n            tag_filter=[\"cv\", \"candidate\"],\n            priority=100,\n            enabled=True,\n            tenant_id=\"acme-corp\",\n            tags=[\"recruitment\", \"hr\"]\n        )\n\n        # Contract analysis for legal team\n        contract_config = OntologyConfig(\n            name=\"legal-contract-analyzer\",\n            agent_schema_id=\"contract-parser-v2\",\n            description=\"Extract key terms from supplier contracts\",\n            mime_type_pattern=\"application/(pdf|msword|vnd.openxmlformats.*)\",\n            tag_filter=[\"legal\", \"contract\"],\n            priority=200,  # Higher priority = runs first\n            enabled=True,\n            provider_name=\"openai\",  # Override default provider\n            model_name=\"gpt-4o\",\n            tenant_id=\"acme-corp\",\n            tags=[\"legal\", \"procurement\"]\n        )\n\n        # Medical records for healthcare\n        medical_config = OntologyConfig(\n            name=\"medical-records-extractor\",\n            agent_schema_id=\"medical-parser-v1\",\n            description=\"Extract diagnoses and treatments from medical records\",\n            mime_type_pattern=\"application/pdf\",\n            tag_filter=[\"medical\", \"patient-record\"],\n            priority=50,\n            enabled=True,\n            tenant_id=\"healthsystem\",\n            tags=[\"medical\", \"hipaa-compliant\"]\n        )\n    \n\nThis agent can search the `ontology_configs` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"title": "Name", "type": "string"}, "agent_schema_id": {"title": "Agent Schema Id", "type": "string"}, "description": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "title": "Description"}, "mime_type_pattern": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "title": "Mime Type Pattern"}, "uri_pattern": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "title": "Uri Pattern"}, "tag_filter": {"default": [], "items": {"type": "string"}, "title": "Tag Filter", "type": "array"}, "priority": {"default": 100, "title": "Priority", "type": "integer"}, "enabled": {"default": true, "title": "Enabled", "type": "boolean"}, "provider_name": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "title": "Provider Name"}, "model_name": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "title": "Model Name"}}, "required": ["name", "agent_schema_id"], "json_schema_extra": {"table_name": "ontology_configs", "entity_key_field": "id", "embedding_fields": ["description"], "fully_qualified_name": "rem.models.entities.ontology_config.OntologyConfig", "tools": ["search_rem"], "default_search_table": "ontology_configs", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "ontology_configs", "entity_key_field": "id", "embedding_fields": ["description"], "fqn": "rem.models.entities.ontology_config.OntologyConfig"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for Resource (resources)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'a579f379-4f1c-5414-8ff4-1382d0f783b7'::uuid,
    'system',
    'Resource',
    '# Resource


    Base content unit in REM.

    Resources are content units that feed into dreaming workflows for moment
    extraction and affinity graph construction. Tenant isolation is provided
    via CoreModel.tenant_id field.
    

## Overview

The `Resource` entity is stored in the `resources` table. Each record is uniquely
identified by its `name` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by name (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM resources LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM resources WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `resources` |
| Entity Key | `name` |
| Embedding Fields | `content` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `typing.Optional[str]`
- **Optional**
- Human-readable resource name (used as graph label). Auto-generated from uri+ordinal if not provided.

### `uri`
- **Type**: `typing.Optional[str]`
- **Optional**
- Content URI or identifier (file path, URL, etc.)

### `ordinal`
- **Type**: `<class ''int''>`
- **Optional**
- Chunk ordinal for splitting large documents (0 for single-chunk resources)

### `content`
- **Type**: `<class ''str''>`
- **Optional**
- Resource content text

### `timestamp`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Resource timestamp (content creation/publication time)

### `category`
- **Type**: `typing.Optional[str]`
- **Optional**
- Resource category (document, conversation, artifact, etc.)

### `related_entities`
- **Type**: `list[dict]`
- **Optional**
- Extracted entities (people, projects, concepts) with metadata

',
    '{"type": "object", "description": "\n    Base content unit in REM.\n\n    Resources are content units that feed into dreaming workflows for moment\n    extraction and affinity graph construction. Tenant isolation is provided\n    via CoreModel.tenant_id field.\n    \n\nThis agent can search the `resources` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Human-readable resource name (used as graph label). Auto-generated from uri+ordinal if not provided.", "entity_key": true, "title": "Name"}, "uri": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Content URI or identifier (file path, URL, etc.)", "title": "Uri"}, "ordinal": {"composite_key": true, "default": 0, "description": "Chunk ordinal for splitting large documents (0 for single-chunk resources)", "title": "Ordinal", "type": "integer"}, "content": {"default": "", "description": "Resource content text", "title": "Content", "type": "string"}, "timestamp": {"description": "Resource timestamp (content creation/publication time)", "format": "date-time", "title": "Timestamp", "type": "string"}, "category": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Resource category (document, conversation, artifact, etc.)", "title": "Category"}, "related_entities": {"description": "Extracted entities (people, projects, concepts) with metadata", "items": {"additionalProperties": true, "type": "object"}, "title": "Related Entities", "type": "array"}}, "required": [], "json_schema_extra": {"table_name": "resources", "entity_key_field": "name", "embedding_fields": ["content"], "fully_qualified_name": "rem.models.entities.resource.Resource", "tools": ["search_rem"], "default_search_table": "resources", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "resources", "entity_key_field": "name", "embedding_fields": ["content"], "fqn": "rem.models.entities.resource.Resource"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for Schema (schemas)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    '2372e956-add6-58b8-a638-758a91a2b6c4'::uuid,
    'system',
    'Schema',
    '# Schema


    Agent schema definition.

    Schemas define agents that can be dynamically loaded into Pydantic AI.
    They store JsonSchema specifications with embedded metadata for tools,
    resources, and system prompts.

    For ontology extraction agents:
    - `provider_configs` enables multi-provider support (test across Anthropic, OpenAI, etc.)
    - `embedding_fields` specifies which output fields should be embedded for semantic search

    Tenant isolation is provided via CoreModel.tenant_id field.
    

## Overview

The `Schema` entity is stored in the `schemas` table. Each record is uniquely
identified by its `id` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by id (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM schemas LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM schemas WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `schemas` |
| Entity Key | `id` |
| Embedding Fields | `content` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `<class ''str''>`
- **Required**
- Human-readable schema name (used as identifier)

### `content`
- **Type**: `<class ''str''>`
- **Optional**
- Markdown documentation and instructions for the schema

### `spec`
- **Type**: `<class ''dict''>`
- **Required**
- JsonSchema specification defining the agent structure and capabilities

### `category`
- **Type**: `typing.Optional[str]`
- **Optional**
- Schema category distinguishing schema types. Values: ''agent'' (AI agents), ''evaluator'' (LLM-as-a-Judge evaluators). Maps directly from json_schema_extra.kind field during ingestion.

### `provider_configs`
- **Type**: `list[dict]`
- **Optional**
- Optional provider configurations for multi-provider testing. Each dict has ''provider_name'' and ''model_name''. Example: [{''provider_name'': ''anthropic'', ''model_name'': ''claude-sonnet-4-5''}]

### `embedding_fields`
- **Type**: `list[str]`
- **Optional**
- JSON paths in extracted_data to embed for semantic search. Example: [''summary'', ''candidate_name'', ''skills''] for CV extraction. Values will be concatenated and embedded using configured embedding provider.

',
    '{"type": "object", "description": "\n    Agent schema definition.\n\n    Schemas define agents that can be dynamically loaded into Pydantic AI.\n    They store JsonSchema specifications with embedded metadata for tools,\n    resources, and system prompts.\n\n    For ontology extraction agents:\n    - `provider_configs` enables multi-provider support (test across Anthropic, OpenAI, etc.)\n    - `embedding_fields` specifies which output fields should be embedded for semantic search\n\n    Tenant isolation is provided via CoreModel.tenant_id field.\n    \n\nThis agent can search the `schemas` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"description": "Human-readable schema name (used as identifier)", "title": "Name", "type": "string"}, "content": {"default": "", "description": "Markdown documentation and instructions for the schema", "title": "Content", "type": "string"}, "spec": {"additionalProperties": true, "description": "JsonSchema specification defining the agent structure and capabilities", "title": "Spec", "type": "object"}, "category": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Schema category distinguishing schema types. Values: ''agent'' (AI agents), ''evaluator'' (LLM-as-a-Judge evaluators). Maps directly from json_schema_extra.kind field during ingestion.", "title": "Category"}, "provider_configs": {"description": "Optional provider configurations for multi-provider testing. Each dict has ''provider_name'' and ''model_name''. Example: [{''provider_name'': ''anthropic'', ''model_name'': ''claude-sonnet-4-5''}]", "items": {"additionalProperties": true, "type": "object"}, "title": "Provider Configs", "type": "array"}, "embedding_fields": {"description": "JSON paths in extracted_data to embed for semantic search. Example: [''summary'', ''candidate_name'', ''skills''] for CV extraction. Values will be concatenated and embedded using configured embedding provider.", "items": {"type": "string"}, "title": "Embedding Fields", "type": "array"}}, "required": ["name", "spec"], "json_schema_extra": {"table_name": "schemas", "entity_key_field": "id", "embedding_fields": ["content"], "fully_qualified_name": "rem.models.entities.schema.Schema", "tools": ["search_rem"], "default_search_table": "schemas", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "schemas", "entity_key_field": "id", "embedding_fields": ["content"], "fqn": "rem.models.entities.schema.Schema"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for Session (sessions)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    '5893fbca-2d8e-5402-ac41-7bac2c0c472a'::uuid,
    'system',
    'Session',
    '# Session


    Conversation session container.

    Groups messages together and supports different modes for normal conversations
    and evaluation/experimentation scenarios.

    For evaluation sessions, stores:
    - original_trace_id: Reference to the original session being evaluated
    - settings_overrides: Model, temperature, prompt overrides
    - prompt: Custom prompt being tested

    Default sessions are lightweight - just a session_id on messages.
    Special sessions store additional metadata for experiments.
    

## Overview

The `Session` entity is stored in the `sessions` table. Each record is uniquely
identified by its `name` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by name (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on description (e.g., `SEARCH "concept" FROM sessions LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM sessions WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `sessions` |
| Entity Key | `name` |
| Embedding Fields | `description` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `<class ''str''>`
- **Required**
- Session name/identifier

### `mode`
- **Type**: `<enum ''SessionMode''>`
- **Optional**
- Session mode: ''normal'' or ''evaluation''

### `description`
- **Type**: `str | None`
- **Optional**
- Optional session description

### `original_trace_id`
- **Type**: `str | None`
- **Optional**
- For evaluation mode: ID of the original session/trace being evaluated

### `settings_overrides`
- **Type**: `dict | None`
- **Optional**
- Settings overrides (model, temperature, max_tokens, system_prompt)

### `prompt`
- **Type**: `str | None`
- **Optional**
- Custom prompt for this session (can override agent prompt)

### `agent_schema_uri`
- **Type**: `str | None`
- **Optional**
- Agent schema used for this session

### `message_count`
- **Type**: `<class ''int''>`
- **Optional**
- Number of messages in this session

### `total_tokens`
- **Type**: `int | None`
- **Optional**
- Total tokens used in this session

',
    '{"type": "object", "description": "\n    Conversation session container.\n\n    Groups messages together and supports different modes for normal conversations\n    and evaluation/experimentation scenarios.\n\n    For evaluation sessions, stores:\n    - original_trace_id: Reference to the original session being evaluated\n    - settings_overrides: Model, temperature, prompt overrides\n    - prompt: Custom prompt being tested\n\n    Default sessions are lightweight - just a session_id on messages.\n    Special sessions store additional metadata for experiments.\n    \n\nThis agent can search the `sessions` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"description": "Session name/identifier", "entity_key": true, "title": "Name", "type": "string"}, "mode": {"$ref": "#/$defs/SessionMode", "default": "normal", "description": "Session mode: ''normal'' or ''evaluation''"}, "description": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Optional session description", "title": "Description"}, "original_trace_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "For evaluation mode: ID of the original session/trace being evaluated", "title": "Original Trace Id"}, "settings_overrides": {"anyOf": [{"additionalProperties": true, "type": "object"}, {"type": "null"}], "default": null, "description": "Settings overrides (model, temperature, max_tokens, system_prompt)", "title": "Settings Overrides"}, "prompt": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Custom prompt for this session (can override agent prompt)", "title": "Prompt"}, "agent_schema_uri": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Agent schema used for this session", "title": "Agent Schema Uri"}, "message_count": {"default": 0, "description": "Number of messages in this session", "title": "Message Count", "type": "integer"}, "total_tokens": {"anyOf": [{"type": "integer"}, {"type": "null"}], "default": null, "description": "Total tokens used in this session", "title": "Total Tokens"}}, "required": ["name"], "json_schema_extra": {"table_name": "sessions", "entity_key_field": "name", "embedding_fields": ["description"], "fully_qualified_name": "rem.models.entities.session.Session", "tools": ["search_rem"], "default_search_table": "sessions", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "sessions", "entity_key_field": "name", "embedding_fields": ["description"], "fqn": "rem.models.entities.session.Session"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for SharedSession (shared_sessions)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    'be5c5711-6c45-5fc4-9cd1-e076599261c7'::uuid,
    'system',
    'SharedSession',
    '# SharedSession


    Session sharing record between users.

    Links a session (identified by session_id from Message records) to a
    recipient user, enabling collaborative access to conversation history.
    

## Overview

The `SharedSession` entity is stored in the `shared_sessions` table. Each record is uniquely
identified by its `id` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by id (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on content (e.g., `SEARCH "concept" FROM shared_sessions LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM shared_sessions WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `shared_sessions` |
| Entity Key | `id` |
| Embedding Fields | None |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `session_id`
- **Type**: `<class ''str''>`
- **Required**
- The session being shared (matches Message.session_id)

### `owner_user_id`
- **Type**: `<class ''str''>`
- **Required**
- User ID of the session owner (the sharer)

### `shared_with_user_id`
- **Type**: `<class ''str''>`
- **Required**
- User ID of the recipient (who can now view the session)

',
    '{"type": "object", "description": "\n    Session sharing record between users.\n\n    Links a session (identified by session_id from Message records) to a\n    recipient user, enabling collaborative access to conversation history.\n    \n\nThis agent can search the `shared_sessions` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "session_id": {"description": "The session being shared (matches Message.session_id)", "title": "Session Id", "type": "string"}, "owner_user_id": {"description": "User ID of the session owner (the sharer)", "title": "Owner User Id", "type": "string"}, "shared_with_user_id": {"description": "User ID of the recipient (who can now view the session)", "title": "Shared With User Id", "type": "string"}}, "required": ["session_id", "owner_user_id", "shared_with_user_id"], "json_schema_extra": {"table_name": "shared_sessions", "entity_key_field": "id", "embedding_fields": [], "fully_qualified_name": "rem.models.entities.shared_session.SharedSession", "tools": ["search_rem"], "default_search_table": "shared_sessions", "has_embeddings": false}}'::jsonb,
    'entity',
    '{"table_name": "shared_sessions", "entity_key_field": "id", "embedding_fields": [], "fqn": "rem.models.entities.shared_session.SharedSession"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- Schema entry for User (users)
INSERT INTO schemas (id, tenant_id, name, content, spec, category, metadata)
VALUES (
    '1ad3d95e-32e9-54d6-ad7d-e39b9ed5018b'::uuid,
    'system',
    'User',
    '# User


    User entity.

    Represents people in the REM system, either as active users
    or entities extracted from content. Tenant isolation is provided
    via CoreModel.tenant_id field.

    Enhanced by dreaming worker:
    - summary: Generated from activity analysis
    - interests: Extracted from resources and sessions
    - activity_level: Computed from recent engagement
    - preferred_topics: Extracted from moment/resource topics
    

## Overview

The `User` entity is stored in the `users` table. Each record is uniquely
identified by its `name` field for lookups and graph traversal.

## Search Capabilities

This schema includes the `search_rem` tool which supports:
- **LOOKUP**: O(1) exact match by name (e.g., `LOOKUP "entity-name"`)
- **FUZZY**: Typo-tolerant search (e.g., `FUZZY "partial" THRESHOLD 0.3`)
- **SEARCH**: Semantic vector search on summary (e.g., `SEARCH "concept" FROM users LIMIT 10`)
- **SQL**: Complex queries (e.g., `SELECT * FROM users WHERE ...`)

## Table Info

| Property | Value |
|----------|-------|
| Table | `users` |
| Entity Key | `name` |
| Embedding Fields | `summary` |
| Tools | `search_rem` |

## Fields

### `id`
- **Type**: `typing.Union[uuid.UUID, str, NoneType]`
- **Optional**
- Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.

### `created_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Entity creation timestamp

### `updated_at`
- **Type**: `<class ''datetime.datetime''>`
- **Optional**
- Last update timestamp

### `deleted_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Soft deletion timestamp

### `tenant_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Tenant identifier for multi-tenancy isolation

### `user_id`
- **Type**: `typing.Optional[str]`
- **Optional**
- Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.

### `graph_edges`
- **Type**: `list[dict]`
- **Optional**
- Knowledge graph edges stored as InlineEdge dicts

### `metadata`
- **Type**: `<class ''dict''>`
- **Optional**
- Flexible metadata storage

### `tags`
- **Type**: `list[str]`
- **Optional**
- Entity tags

### `name`
- **Type**: `<class ''str''>`
- **Required**
- User name (human-readable, used as graph label)

### `email`
- **Type**: `typing.Optional[str]`
- **Optional**
- User email address

### `role`
- **Type**: `typing.Optional[str]`
- **Optional**
- User role (employee, contractor, external, etc.)

### `tier`
- **Type**: `<enum ''UserTier''>`
- **Optional**
- User subscription tier (free, basic, pro) for feature gating

### `anonymous_ids`
- **Type**: `list[str]`
- **Optional**
- Linked anonymous session IDs used for merging history

### `sec_policy`
- **Type**: `<class ''dict''>`
- **Optional**
- Security policy configuration (JSON, extensible for custom policies)

### `summary`
- **Type**: `typing.Optional[str]`
- **Optional**
- LLM-generated user profile summary (updated by dreaming worker)

### `interests`
- **Type**: `list[str]`
- **Optional**
- User interests extracted from activity

### `preferred_topics`
- **Type**: `list[str]`
- **Optional**
- Frequently discussed topics in kebab-case

### `activity_level`
- **Type**: `typing.Optional[str]`
- **Optional**
- Activity level: active, moderate, inactive

### `last_active_at`
- **Type**: `typing.Optional[datetime.datetime]`
- **Optional**
- Last activity timestamp

',
    '{"type": "object", "description": "\n    User entity.\n\n    Represents people in the REM system, either as active users\n    or entities extracted from content. Tenant isolation is provided\n    via CoreModel.tenant_id field.\n\n    Enhanced by dreaming worker:\n    - summary: Generated from activity analysis\n    - interests: Extracted from resources and sessions\n    - activity_level: Computed from recent engagement\n    - preferred_topics: Extracted from moment/resource topics\n    \n\nThis agent can search the `users` table using the `search_rem` tool. Use REM query syntax: LOOKUP for exact match, FUZZY for typo-tolerant search, SEARCH for semantic similarity, or SQL for complex queries.", "properties": {"id": {"anyOf": [{"format": "uuid", "type": "string"}, {"type": "string"}, {"type": "null"}], "default": null, "description": "Unique identifier (UUID or string, generated per model type). Generated automatically if not provided.", "title": "Id"}, "created_at": {"description": "Entity creation timestamp", "format": "date-time", "title": "Created At", "type": "string"}, "updated_at": {"description": "Last update timestamp", "format": "date-time", "title": "Updated At", "type": "string"}, "deleted_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Soft deletion timestamp", "title": "Deleted At"}, "tenant_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Tenant identifier for multi-tenancy isolation", "title": "Tenant Id"}, "user_id": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Owner user identifier (tenant-scoped). This is a VARCHAR(256), not a UUID, to allow flexibility for external identity providers. Typically generated as a hash of the user''s email address. In future, other strong unique claims (e.g., OAuth sub, verified phone) could also be used for generation.", "title": "User Id"}, "graph_edges": {"description": "Knowledge graph edges stored as InlineEdge dicts", "items": {"additionalProperties": true, "type": "object"}, "title": "Graph Edges", "type": "array"}, "metadata": {"additionalProperties": true, "description": "Flexible metadata storage", "title": "Metadata", "type": "object"}, "tags": {"description": "Entity tags", "items": {"type": "string"}, "title": "Tags", "type": "array"}, "name": {"description": "User name (human-readable, used as graph label)", "entity_key": true, "title": "Name", "type": "string"}, "email": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "User email address", "title": "Email"}, "role": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "User role (employee, contractor, external, etc.)", "title": "Role"}, "tier": {"$ref": "#/$defs/UserTier", "default": "free", "description": "User subscription tier (free, basic, pro) for feature gating"}, "anonymous_ids": {"description": "Linked anonymous session IDs used for merging history", "items": {"type": "string"}, "title": "Anonymous Ids", "type": "array"}, "sec_policy": {"additionalProperties": true, "description": "Security policy configuration (JSON, extensible for custom policies)", "title": "Sec Policy", "type": "object"}, "summary": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "LLM-generated user profile summary (updated by dreaming worker)", "title": "Summary"}, "interests": {"description": "User interests extracted from activity", "items": {"type": "string"}, "title": "Interests", "type": "array"}, "preferred_topics": {"description": "Frequently discussed topics in kebab-case", "items": {"type": "string"}, "title": "Preferred Topics", "type": "array"}, "activity_level": {"anyOf": [{"type": "string"}, {"type": "null"}], "default": null, "description": "Activity level: active, moderate, inactive", "title": "Activity Level"}, "last_active_at": {"anyOf": [{"format": "date-time", "type": "string"}, {"type": "null"}], "default": null, "description": "Last activity timestamp", "title": "Last Active At"}}, "required": ["name"], "json_schema_extra": {"table_name": "users", "entity_key_field": "name", "embedding_fields": ["summary"], "fully_qualified_name": "rem.models.entities.user.User", "tools": ["search_rem"], "default_search_table": "users", "has_embeddings": true}}'::jsonb,
    'entity',
    '{"table_name": "users", "entity_key_field": "name", "embedding_fields": ["summary"], "fqn": "rem.models.entities.user.User"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    content = EXCLUDED.content,
    spec = EXCLUDED.spec,
    category = EXCLUDED.category,
    metadata = EXCLUDED.metadata,
    updated_at = CURRENT_TIMESTAMP;

-- ============================================================================
-- RECORD MIGRATION
-- ============================================================================

INSERT INTO rem_migrations (name, type, version)
VALUES ('install_models.sql', 'models', '1.0.0')
ON CONFLICT (name) DO UPDATE
SET applied_at = CURRENT_TIMESTAMP,
    applied_by = CURRENT_USER;

DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'REM Model Schema Applied: 12 tables';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  ✓ feedbacks';
    RAISE NOTICE '  ✓ files (1 embeddable fields)';
    RAISE NOTICE '  ✓ image_resources (1 embeddable fields)';
    RAISE NOTICE '  ✓ messages (1 embeddable fields)';
    RAISE NOTICE '  ✓ moments (1 embeddable fields)';
    RAISE NOTICE '  ✓ ontologies';
    RAISE NOTICE '  ✓ ontology_configs (1 embeddable fields)';
    RAISE NOTICE '  ✓ resources (1 embeddable fields)';
    RAISE NOTICE '  ✓ schemas (1 embeddable fields)';
    RAISE NOTICE '  ✓ sessions (1 embeddable fields)';
    RAISE NOTICE '  ✓ shared_sessions';
    RAISE NOTICE '  ✓ users (1 embeddable fields)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next: Run background indexes if needed';
    RAISE NOTICE '  rem db migrate --background-indexes';
    RAISE NOTICE '============================================================';
END $$;