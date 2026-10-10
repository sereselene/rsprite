std = "max"

max_line_length = 200

ignore = {
	"212/self",
}

globals = {
	"ui",
	"id",
	"Event",
	"Plugin",
	"PersistentDB",
	"config",
	"Vector4",
	"PluginShutdown",
	"rsprite",
}

exclude_files = {
	"node_modules",
	"dist",
	"standalone",
}

files["examples"] = {
	globals = { "prettyui" },
}

files["plugins/rsprite-finder"] = {
	globals = { "prettyui" },
}

files["tests"] = {
	globals = { "prettyui" },
	read_globals = { "selftest" },
}
