CREATE TABLE user_project_acls
(
    project_id   UUID REFERENCES projects  NOT NULL,
    user_id      UUID REFERENCES users     NOT NULL,
    can_write    BOOLEAN                   NOT NULL,
    PRIMARY KEY(project_id, user_id)
);