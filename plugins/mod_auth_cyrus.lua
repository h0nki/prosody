-- Prosody IM
-- Copyright (C) 2008-2010 Matthew Wild
-- Copyright (C) 2008-2010 Waqas Hussain
-- Copyright (C) 2010 Jeff Mitchell
--
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local log = require "util.logger".init("usermanager");
local type = type;
local ipairs = ipairs;
local jid_bare = require "util.jid".bare;
local config = require "core.configmanager";

local cyrus_service_realm = module:get_option("cyrus_service_realm");
local cyrus_service_name = module:get_option("cyrus_service_name");
local cyrus_application_name = module:get_option("cyrus_application_name");

prosody.unlock_globals(); --FIXME: Figure out why this is needed and
						  -- why cyrussasl isn't caught by the sandbox
local cyrus_new = require "util.sasl_cyrus".new;
prosody.lock_globals();
local new_sasl = function(realm)
	return cyrus_new(
		cyrus_service_realm or realm,
		cyrus_service_name or "xmpp",
		cyrus_application_name or "prosody"
	);
end

function new_default_provider(host)
	local provider = { name = "cyrus" };
	log("debug", "initializing default authentication provider for host '%s'", host);

	function provider.test_password(username, password)
		return nil, "Legacy auth not supported with Cyrus SASL.";
	end

	function provider.get_password(username)
		return nil, "Passwords unavailable for Cyrus SASL.";
	end
	
	function provider.set_password(username, password)
		return nil, "Passwords unavailable for Cyrus SASL.";
	end

	function provider.user_exists(username)
		return true;
	end

	function provider.create_user(username, password)
		return nil, "Account creation/modification not available with Cyrus SASL.";
	end

	function provider.get_sasl_handler()
		local realm = module:get_option("sasl_realm") or module.host;
		return new_sasl(realm);
	end

	function provider.is_admin(jid)
		local admins = config.get(host, "core", "admins");
		if admins ~= config.get("*", "core", "admins") and type(admins) == "table" then
			jid = jid_bare(jid);
			for _,admin in ipairs(admins) do
				if admin == jid then return true; end
			end
		elseif admins then
			log("error", "Option 'admins' for host '%s' is not a table", host);
		end
		return is_admin(jid); -- Test whether it's a global admin instead
	end
	return provider;
end

module:add_item("auth-provider", new_default_provider(module.host));
