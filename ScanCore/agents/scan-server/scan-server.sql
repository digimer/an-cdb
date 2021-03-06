-- NOTES 
--     - The public table must have a column called '<table_name>_id' which is a 'bigserial'.
--     - The history schema must have a column called 'history_id' which is a 'bigserial' as well.
--     - There must be a column called 'X_host_uuid' that is a foreign key to  'hosts -> host_uuid'.
--     
-- Servers are distinct entities that can exist on either node or move entirely to another Anvil!. Users
-- must be aware of this and account for a server moving away and coming back over time. This can be 
-- accounted for, in part, but having the agent scan 'virsh --connect qemu+ssh://root@<peer>/system ...'. The
-- 'server_host_uuid', then, simply indicates which host/node gathered the data.
-- 

-- This stores information about the server.
CREATE TABLE server (
	server_uuid		uuid				not null	primary key,	-- This comes from the server's XML definition file.
	server_host_uuid	uuid				not null,
	server_name		text				not null,
	server_stop_reason	text,								-- Set by Striker to 'clean' when stopped via the webui. This prevents anvil-safe-start from starting it on node boot.
	server_start_group	integer				not null	default 1,	-- Setting this to '9999' will prevent it from booting at all.
	server_start_delay	integer				not null	default 0,	-- How many seconds to delay booting for after the last server in the previous group boots.
	modified_date		timestamp with time zone	not null
);
ALTER TABLE server OWNER TO #!variable!user!#;

CREATE TABLE history.server (
	history_id		bigserial,
	server_uuid		uuid,
	server_host_uuid	uuid,
	server_name		text,
	server_stop_reason	text,
	server_start_group	integer,
	server_start_delay	integer,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.server OWNER TO #!variable!user!#;

CREATE FUNCTION history_server() RETURNS trigger
AS $$
DECLARE
	history_server RECORD;
BEGIN
	SELECT INTO history_server * FROM server WHERE server_uuid = new.server_uuid;
	INSERT INTO history.server
		(server_uuid,
		 server_host_uuid, 
		 server_name, 
		 server_stop_reason, 
		 server_start_group, 
		 server_start_delay, 
		 modified_date)
	VALUES
		(history_server.server_uuid, 
		 history_server.server_host_uuid, 
		 history_server.server_name, 
		 history_server.server_stop_reason, 
		 history_server.server_start_group, 
		 history_server.server_start_delay, 
		 history_server.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_server() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_server
	AFTER INSERT OR UPDATE ON server
	FOR EACH ROW EXECUTE PROCEDURE history_server();
