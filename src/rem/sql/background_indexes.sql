-- Background index creation
-- Run AFTER initial data load to avoid blocking writes

-- HNSW vector index for embeddings_files
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_files_vector_hnsw
ON embeddings_files
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_image_resources
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_image_resources_vector_hnsw
ON embeddings_image_resources
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_messages
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_messages_vector_hnsw
ON embeddings_messages
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_moments
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_moments_vector_hnsw
ON embeddings_moments
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_ontology_configs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_ontology_configs_vector_hnsw
ON embeddings_ontology_configs
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_resources
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_resources_vector_hnsw
ON embeddings_resources
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_schemas
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_schemas_vector_hnsw
ON embeddings_schemas
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_sessions
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_sessions_vector_hnsw
ON embeddings_sessions
USING hnsw (embedding vector_cosine_ops);

-- HNSW vector index for embeddings_users
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_embeddings_users_vector_hnsw
ON embeddings_users
USING hnsw (embedding vector_cosine_ops);
