std = "max"

max_line_length = 200

ignore = {
	"212/self",
}

read_globals = {
	"ui",
	"id",
	"Event",
	"Plugin",
	"PersistentDB",
	"config",
	"rsprite",
}

globals = {
	"PluginShutdown",
}

exclude_files = {
	"node_modules",
}

files["examples"] = {
	globals = { "prettyui" },
}

files["plugins/rsprite-finder"] = {
	globals = { "prettyui" },
}

files["scripts"] = {
	read_globals = { "selftest" },
}

files["tests"] = {
	globals = { "prettyui", "rsprite", "ui", "id", "Event", "Plugin", "PersistentDB", "config" },
	read_globals = { "selftest" },
}
