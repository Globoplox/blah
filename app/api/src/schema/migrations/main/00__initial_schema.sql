CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

CREATE TABLE blobs
(
    id              UUID PRIMARY KEY        NOT NULL DEFAULT gen_random_uuid(),
    content_type    VARCHAR(50)             NOT NULL,
    size            INT                     NOT NULL,
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW()
);

CREATE TABLE users
(
    id                      UUID PRIMARY KEY        NOT NULL DEFAULT gen_random_uuid(),
    name                    VARCHAR(50)             NOT NULL,
    tag                     VARCHAR(4)              NOT NULL,
    avatar_blob_id          UUID REFERENCES blobs   DEFAULT NULL,
    created_at              TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    allowed_blob_size       INT                     NOT NULL,
    allowed_project         INT                     NOT NULL,
    allowed_concurrent_job  INT                     NOT NULL,
    allowed_concurrent_tty  INT                     NOT NULL,
    UNIQUE(name, tag)
);

CREATE TABLE credentials
(
    id              UUID PRIMARY KEY      NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users NOT NULL UNIQUE,
    email           VARCHAR(100)          NOT NULL UNIQUE,
    password_hash   VARCHAR(60)           NOT NULL
);

CREATE TABLE projects
(
    id          UUID PRIMARY KEY                    NOT NULL DEFAULT gen_random_uuid(),
    name        VARCHAR(50)                         NOT NULL,
    description VARCHAR(1000)                       DEFAULT NULL,
    owner_id     UUID REFERENCES users              NOT NULL,
    public      BOOLEAN                             NOT NULL,
    avatar_blob_id  UUID REFERENCES blobs           DEFAULT NULL,
    allowed_blob_size        INT                    NOT NULL,
    allowed_file_amount      INT                    NOT NULL,
    created_at  TIMESTAMPTZ                         NOT NULL DEFAULT NOW(),
    UNIQUE(owner_id, name)
);

CREATE TABLE project_files
(
    id              UUID PRIMARY KEY                NOT NULL DEFAULT gen_random_uuid(),
    project_id      UUID REFERENCES projects        NOT NULL,
    blob_id         UUID REFERENCES blobs           UNIQUE,
    is_directory    BOOLEAN                         GENERATED ALWAYS AS (blob_id IS NULL) STORED,
    path            VARCHAR(1000)                   UNIQUE DEFAULT NULL,
    author_id       UUID REFERENCES users           NOT NULL,
    editor_id       UUID REFERENCES users           NOT NULL,    
    authored_at     TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    file_edited_at  TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    UNIQUE(project_id, path)
);