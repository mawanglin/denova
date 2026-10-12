package buildinfo

// Version is injected by release builds. The default keeps source/dev runs from
// treating themselves as installable release binaries.
var Version = "dev"

// DevelopmentVersion is the public capability target of this source tree.
const DevelopmentVersion = "0.6.0"

const Repository = "alfredxw/denova"

// InstallManager names the host package manager that owns program files, such
// as "fnos". Host packaging injects it; a managed installation is upgraded by
// that manager and must never replace its own files.
var InstallManager = ""
