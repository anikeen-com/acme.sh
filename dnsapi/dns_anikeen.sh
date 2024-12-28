#!/usr/bin/env sh
# shellcheck disable=SC2034

dns_anikeen_info='Anikeen Cloud
Site: Anikeen.cloud
Docs: github.com/acmesh-official/acme.sh/wiki/dnsapi2#dns_anikeen
Options:
 ANIKEEN_API_KEY API Key
Issues: github.com/acmesh-official/acme.sh/issues/6175
Author: Maurice Preuß <maurice@anikeen.com>
'

### Public functions

# Usage: add _acme-challenge.www.domain.com "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
# Used to add txt record
dns_anikeen_add() {
  fulldomain="$1"
  txtvalue="$2"

  _info "Using Anikeen Cloud API to add TXT record"

  _check_anikeen_api_key || return 1

  _debug "Finding zone for domain: $fulldomain"
  _anikeen_find_zone "$fulldomain"
  if [ -z "$_domain_id" ]; then
    _err "Domain not found in Anikeen Cloud API"
    return 1
  fi

  _debug "Adding TXT record"
  _anikeen_add_record "$_domain_id" "$fulldomain" "TXT" "$txtvalue"
}

# Usage: fulldomain txtvalue
# Used to remove the txt record after validation
dns_anikeen_rm() {
  fulldomain="$1"
  txtvalue="$2"

  _info "Using Anikeen Cloud API to remove TXT record"

  _check_anikeen_api_key || return 1

  _debug "Finding zone for domain: $fulldomain"
  _anikeen_find_zone "$fulldomain"
  if [ -z "$_domain_id" ]; then
    _err "Domain not found in Anikeen Cloud API"
    return 1
  fi

  _debug "Removing TXT record"
  _anikeen_delete_record "$_domain_id" "$fulldomain" "TXT" "$txtvalue"
}

###  Private functions

_check_anikeen_api_key() {
  ANIKEEN_API_KEY="${ANIKEEN_API_KEY:-$(_readaccountconf_mutable ANIKEEN_API_KEY)}"
  if [ -z "$ANIKEEN_API_KEY" ]; then
    ANIKEEN_API_KEY=""
    _err "You don't specify the Anikeen Cloud api key yet."
    _err "Please create your key and try again."
    return 1
  fi

  # save the credentials to the account conf file
  _saveaccountconf_mutable ANIKEEN_API_KEY "$ANIKEEN_API_KEY"

  _debug "API Key is set"

  export _H1="Accept: application/json"
  export _H1="Content-Type: application/json"
  export _H2="Authorization: Bearer $ANIKEEN_API_KEY"

  _debug "Headers set"
}

_anikeen_find_zone() {
  domain="$1"

  while [ -n "$domain" ]; do
    _debug2 "Finding zone for domain: $domain"

    response=$(_get "https://api.anikeen.cloud/v1/zones?name=$domain")
    _debug2 response "$response"

    if echo "$response" | grep -q '"data"'; then
      _domain_id=$(echo "$response" | _egrep_o '"data":\[\{"id":"[a-zA-Z0-9]*"' | _egrep_o '[a-zA-Z0-9]{26}')

      if [ -n "$_domain_id" ]; then
        _info "Using zone $_domain_id for domain $domain"
        return 0
      fi
    fi

    domain="${domain#*.}"
  done

  _err "No matching zone found for domain $1"
  return 1
}

_anikeen_add_record() {
  domain_id="$1"
  name="$2"
  type="$3"
  content="$4"

  data="{\"name\":\"$name\",\"type\":\"$type\",\"content\":\"\\\"$content\\\"\",\"ttl\":300,\"prio\":0}"
  response=$(_post "$data" "https://api.anikeen.cloud/v1/zones/$domain_id/records" "", "POST")

  if [ "$?" != "0" ]; then
    _err "Failed to add record: $response"
    return 1
  fi

  _debug2 response "$response"

  _info "TXT record added successfully"
}

_anikeen_delete_record() {
  domain_id="$1"
  name="$2"
  type="$3"
  content="$4"

  response=$(_get "https://api.anikeen.cloud/v1/zones/$domain_id/records?name=$name&type=$type&content=\"$content\"")

  _debug2 response "$response"

  record_id=$(echo "$response" | _egrep_o '"data":\[\{"id":[0-9]*' | _egrep_o '[0-9]*')

  if [ -z "$record_id" ]; then
    _err "Record not found"
    return 1
  fi

  response=$(_post "", "https://api.anikeen.cloud/v1/zones/$domain_id/records/$record_id", "", "DELETE")

  if [ "$?" != "0" ]; then
    _err "Failed to delete record: $response"
    return 1
  fi

  _debug2 response "$response"

  _info "TXT record removed successfully"
}
