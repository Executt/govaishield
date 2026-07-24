CREATE TRIGGER trg_orgaos_updated BEFORE UPDATE ON admin.orgaos FOR EACH ROW EXECUTE FUNCTION core.update_timestamp();
CREATE TRIGGER trg_providers_updated BEFORE UPDATE ON core.ai_providers FOR EACH ROW EXECUTE FUNCTION core.update_timestamp();
CREATE TRIGGER trg_policies_updated BEFORE UPDATE ON policy.policies FOR EACH ROW EXECUTE FUNCTION core.update_timestamp();
