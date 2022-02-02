#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /tools/openssl/Sanity/OpenSSL-and-similar
#   Description: Test checking if crypto policy which is set on the machinein TLS connection.
#   Author: Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2022 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="openssl"
DEFAULT="TRUE"
LEGACY="TRUE"
CONNECTION="TRUE"
SERVER_OUTPUT="server_output"
CLIENT_OUTPUT="client_output"
TPM=0

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
    rlPhaseEnd


    if [ "$CONNECTION" == "TRUE" ]; then
    rlPhaseStartTest "Testing establishing of TLS connection"
        rlRun "update-crypto-policies --set DEFAULT" 0
        rlRun "openssl req -x509 -newkey rsa -keyout key.pem -out server.pem -days 365 -nodes -subj "/CN=localhost" " 0
        rlRun "timeout 8 openssl s_client >> $CLIENT_OUTPUT" &
        rlRun "timeout 7 openssl s_server -key key.pem -cert server.pem >> $SERVER_OUTPUT " 124
        rlRun "grep 'CONNECTED' $CLIENT_OUTPUT" 0 "Checking if client was connected"
        rlRun "grep 'ACCEPT' $SERVER_OUTPUT" 0 "Checking if server accept session"
	if rlRun "grep -r 'CONNECTED' $CLIENT_OUTPUT" ; then
	    TMP=$((TMP+1))
	fi
#	rlRun "cp $CLIENT_OUTPUT client"
#       rlRun "cp $SERVER_OUTPUT server"
        rlRun "rm -rf key.pem server.pem $CLIENT_OUTPUT $SERVER_OUTPUT"
    rlPhaseEnd
    fi
	
    if [ $TMP == 1 ]; then
        if [ "$DEFAULT" == "TRUE" ]; then
        rlPhaseStartTest "Testing default crypto-policy settings"
            rlRun "update-crypto-policies --set DEFAULT" 0 
            rlRun "openssl req -x509 -newkey rsa -keyout key.pem -out server.pem -days 365 -nodes -subj "/CN=localhost" " 0	
            rlRun "timeout 7 openssl s_client >> $CLIENT_OUTPUT" &
	    rlRun "timeout 8 openssl s_server -key key.pem -cert server.pem >> $SERVER_OUTPUT" 124
            rlRun "grep -r 'DHE-DSS-DES-CBC3-SHA' $SERVER_OUTPUT" 1 "Shared Ciphers DEFAULT"
            rlRun "grep -r 'RSA+SHA1:DSA+SHA1' $SERVER_OUTPUT" 1 "Signature Algorithms DEFAULT"
            rlRun "grep -r 'RSA+SHA1' $SERVER_OUTPUT" 1 "Shared Signature Algorithms DEFAULT"
            rlRun "rm -rf key.pem server.pem $CLIENT_OUTPUT $SERVER_OUTPUT" 
        rlPhaseEnd
        fi
    fi

    if [ $TMP == 1 ]; then
        if [ "$LEGACY" == "TRUE" ]; then
        rlPhaseStartTest "Testing legacy crypto-policy settings"
   	    rlRun "update-crypto-policies --set LEGACY" 0 
            rlRun " openssl req -x509 -newkey rsa -keyout key.pem -out server.pem -days 365 -nodes -subj "/CN=localhost" " 0
            rlRun "timeout 8 openssl s_client >> $CLIENT_OUTPUT" &
            rlRun "timeout 7 openssl s_server -key key.pem -cert server.pem >> $SERVER_OUTPUT" 124
	    rlRun "grep -r 'DHE-DSS-DES-CBC3-SHA' $SERVER_OUTPUT" 0 "Shared Ciphers LEGACY"
            rlRun "grep -r 'RSA+SHA1:DSA+SHA1' $SERVER_OUTPUT" 0 "Signature Algorithms LEGACY"
	    rlRun "grep -r 'RSA+SHA1' $SERVER_OUTPUT" 0 "Shared Signature Algorithms LEGACY"
	    rlRun "rm -rf key.pem server.pem $CLIENT_OUTPUT $SERVER_OUTPUT"
        rlPhaseEnd
        fi
    fi

    rlPhaseStartCleanup
	sleep 2
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
