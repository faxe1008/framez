#!/bin/bash
#
# Bootstrap a new zephyr base firmware repo clone
#
# * install a new virtualenv
# * install 'west' python3 module
# * init zephyr instal with 'west'
# * update zephyr install with 'west'
# * update submodules

set -eu

if [ "x$(uname -s)" == "xDarwin" ]; then
        if [ -e "${SCRIPT_NAME:-}" ] && [ ! -d "${SCRIPT_NAME:-}" ] && [ ! -f "${SCRIPT_NAME:-}" ]; then
                SCRIPT_NAME="$(readlink "${0}")"
                if [ "x${SCRIPT_NAME:0:1}" != "x/" ]; then
                        SCRIPT_NAME="$(dirname "${0}")/${SCRIPT_NAME}"
                fi
        else
                SCRIPT_NAME="${0}"
        fi
        SCRIPT_PATH=$(cd "$(dirname "${SCRIPT_NAME}")"; pwd)
else
        SCRIPT_NAME="$(readlink -f "${0}")"
        SCRIPT_PATH="$(dirname "${SCRIPT_NAME}")"
fi

make_abspath () {
	[ ! -z  "${1}" ] || { echo "Need argument: make_abspath"; exit 1;}
	(cd "${1}" ; pwd)
}


msg_err () {
	echo "$(tput setaf 1)Error: ${*}$(tput sgr0)" >&2
}

msg_info () {
	echo "$(tput setaf 3)Info: ${*}$(tput sgr0)" >&2
}

msg_warn () {
	echo "$(tput setaf 1)Warn:$(tput setaf 3) ${*}$(tput sgr0)" >&2
}

update_gitsubmodules () {
	msg_info "Updating own submodules"
	pushd "${REPO_ROOT}" >/dev/null 2>&1 || exit 1

	# workaround for migrating zephyr from submodule to west module
	if git submodule status vendor/zephyr >/dev/null 2>&1; then
		msg_err "Old zephyr submodule detected, please remove it by executing: "
		msg_info "git submodule deinit vendor/zephyr"
		msg_info "rm -rf vendor/zephyr"
		exit 1
	fi
	# end workarond

	git submodule update --init || { msg_err "Failed to update repo submodules" ; exit 1; }
	popd
}

REPO_ROOT="$(make_abspath "${SCRIPT_PATH}/..")"
WEST_INST_DIR="${REPO_ROOT}/vendor"
__ZEPHYR_BASE="${WEST_INST_DIR}/zephyr"

venv_name=".venv_zephyr"
venv_path="${REPO_ROOT}/.venv_zephyr"

echo "venv: ${venv_path}"


usage () {
	cat <<- EOF
		Boostrap or update project tools and source dependencies for '$(basename "${REPO_ROOT}")' project

		Following tasks will be performed:
		    * install a new python3 virtualenv (to avoid version conflicts)
		      to '.venv_zephyr' in the repository root
		    * (temporary) activate the virtual env
		    * install 'west' python3 module    (needed for zephyr source management)
		    * update/init zephyr source code and modules with 'west'
		    * install zephyr python deps
		    * install own python deps
		    * update/init own git submodules

		Required dependecies are python3, pip3, (python3-) venv module, SDK


		Troubleshoot: If any problems occur during upgrade, you can remove the installations folders to get a fresh installation:
		python3 virtualenv:
		    .venv_zephyr

		west installation/config:
		    ${REPO_ROOT}/.west

		zephyr installation
		    ${WEST_INST_DIR}/zephyr

		zephyr modules installation
		    ${WEST_INST_DIR}/

		Afterwards rerun this script

	EOF

}

if [ ! -z "${1:-}" ]; then
	usage
	exit 0
fi


check_virtual_active () {
	local ve_install_path
	[ -z "${VIRTUAL_ENV:-}" ] || {
		msg_err "currently virtualenv activated"
		msg_info "Please run this script in a new shell"
		exit 1;
	}

}

check_virtual_env () {
	local p_install_path
	p_install_path="$(which python3)" || { msg_err "python3 not installed!"; exit 1; }

	if echo "${p_install_path}" | grep '^/usr'; then
		msg_err "virtual env not installed or activated properly"
		exit 1
	fi
}


create_virtual_env () {
	[ -z "${venv_path}" ] && { msg_err "Failed to find virtualenv path ${venv_path}"; exit 1; }
	if [ ! -d "${venv_path}" ]; then
		msg_info "Creating python virtualenv in ${venv_path}"
		python3 -mvenv "${venv_path}" || { msg_err "Failed to create virtualenv in ${venv_path}"; exit 1; }
	else
		if [ ! -f "${venv_path}/bin/activate" ]; then
			msg_err "virtualenv in ${venv_path} exists, but is misconfigured, remove it and restart this script"; exit 1
		else
			msg_info "virtualenv in ${venv_path} exists, skipping"
		fi
	fi
}



install_west () {
	check_virtual_env
	# may be ncessary for installing wheels from requirements.txt on some platforms
	python3 -m pip install --upgrade wheel
	if ! which west > /dev/null; then
		msg_info "Installing 'west' (zephyr meta tool)"
		python3 -mpip install west || { msg_err "Failed to install west in ${venv_path}"; exit 1; }
	else
		msg_info "Checking updates for 'west' (zephyr meta tool)"
		python3 -mpip install --upgrade west || { msg_err "Failed to upgrade west in ${venv_path}"; exit 1; }
	fi
}


init_west () {
	check_virtual_env

	mkdir -p "${WEST_INST_DIR}"
	pushd "${WEST_INST_DIR}" >/dev/null 2>&1 || exit 1
	msg_info "Vendor directory is $(pwd)"

	if [ ! -d "${REPO_ROOT}/.west" ]; then
		msg_info "Initializing zephyr installation in '${WEST_INST_DIR}'"
		# west will always put itself one up. Force it to be repo_root
		west init -l --mf ../west.yml .  || exit 1

		# replace paths and file path in config
		mv "${REPO_ROOT}/.west/config" "${REPO_ROOT}/.west/config.bkp"
		cat "${REPO_ROOT}/.west/config.bkp" |
			sed 's/path = .*/path = ./' |
			sed 's/file = .*/file = west.yml/' > "${REPO_ROOT}/.west/config"
		rm "${REPO_ROOT}/.west/config.bkp"
	fi
	popd >/dev/null 2>&1
}

update_zephyr_deps () {
	pushd "${WEST_INST_DIR}" >/dev/null 2>&1 || exit 1
	msg_info "Updating zephyr dependencies"
	west update || exit 1
	popd >/dev/null 2>&1
}

update_zephyr_tools () {
	msg_info "Updating zephyr python tools"
	check_virtual_env

	pushd "${WEST_INST_DIR}/zephyr/" >/dev/null

	python3 -mpip install --upgrade -r "${WEST_INST_DIR}/zephyr/scripts/requirements-base.txt" || exit 1
	python3 -mpip install --upgrade -r "${WEST_INST_DIR}/zephyr/scripts/requirements-extras.txt" || exit 1

	popd >/dev/null

}

update_own_tools () {
	msg_info "Updating own python tools"
	check_virtual_env
	if [ -f "${REPO_ROOT}/scripts/requirements.txt" ]; then
		python3 -mpip install --upgrade -r "${REPO_ROOT}/scripts/requirements.txt" || exit 1
	fi
}



msg_info "Setting up/updating installation in $(make_abspath "${REPO_ROOT}/..")"

check_virtual_active

update_gitsubmodules

create_virtual_env

source "${venv_path}/bin/activate" || {  msg_err "Failed to activate virtualenv in ${venv_path}"; exit 1; }

check_virtual_env

install_west

init_west

update_zephyr_deps

update_zephyr_tools

update_own_tools


echo "$(tput setaf 2)Done$(tput sgr0)"
echo ""

if [ ! -f "${HOME}/.zephyrrc" ]; then
	msg_warn "SDK not installed or not configured in ~/.zephyrrc, please install the zephyr SDK as per official guide"
fi

cat <<- EOF

	Every thing is now updated and installed.

	$(tput setaf 3)Setup your shell for building with:$(tput sgr0)
	  source zephyr-init-env

EOF
