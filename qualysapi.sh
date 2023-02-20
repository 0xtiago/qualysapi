#!/bin/bash

# Check existence of qualys.config
if [[ ! -f qualys.config ]] ; then
    echo 'File "qualys.config" is not there. Rename the file "qualys_sample.config" and configure it. Aborting.'
    exit
fi

# Importing local configs
. qualys.config


if [[ $QUALYS_LAUNCH_MODE == 1 ]]; then  
	echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Variaveis de ambiente e credenciais obtidas de qualys.conf local."  
fi
if [[ $QUALYS_LAUNCH_MODE == 2 ]]; then  
		echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Using Github Secrets."
		if [ ! -z "$QUALYS_USER_PASS" ] || [! -z "$QUALYS_WEBAPP_ID" ]; then
			echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Found Github secrets and variables set up."
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") | Github neither secrets nor variables present. Verify your Github secrets setup."
			exit
		fi	
else
	echo "$(date "+%Y-%m-%d %H:%M:%S") | No environment setup was found. Check our README at https://github.com/0xtiago/qualysapi."
	exit
fi

#Confs de espera
WAIT_SCAN=120
WAIT_REPORT=120

#Formato da Data
DATE_FORMAT="$(date "+%Y-%m-%d %H:%M:%S")"

#Criando pastas locais caso não existam
mkdir -p $PWD/xml
mkdir -p $PWD/log

# # # F I M   D O   S E T U P # # # 

TIME_SCAN="$(date "+%Y-%m-%d %H:%M:%S")"
echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Configurando WEB APPLICATION SCAN."


#O XML abaixo é utilizado para enviar os parâmetros solicitados na chamada API
cat <<EOF > $PWD/xml/wasscan.xml
<ServiceRequest>
   <data>
      <WasScan>
         <name>$QUALYS_PROJECT_NAME $TIME_SCAN</name>
         <type>VULNERABILITY</type>
         <target>
            <webApp>
               <id>$QUALYS_WEBAPP_ID</id>
            </webApp>
            <webAppAuthRecord>
               <isDefault>true</isDefault>
            </webAppAuthRecord>
            <scannerAppliance>
               <type>$QUALYS_SCANNER_TYPE</type>
            </scannerAppliance>
         </target>
         <profile>
            <id>$QUALYS_OPTION_PROFILE_ID</id>
         </profile>
      </WasScan>
   </data>
</ServiceRequest>
EOF


#Chama API do Qualys
echo "$TIME_SCAN | $QUALYS_PROJECT_NAME | Solicitando scan."
curl -s -u ""$QUALYS_USER:$QUALYS_USER_PASS"" -H "content-type: text/xml" -X "POST" --data-binary @- "$QUALYS_URL/qps/rest/3.0/launch/was/wasscan" -o $PWD/log/wasscan.log < $PWD/xml/wasscan.xml

#Guarda ID do scan para monitorar o andamento e verifica o scan status
QUALYS_SCAN_ID=`cat $PWD/log/wasscan.log | sed -n 's:.*<id>\(.*\)</id>.*:\1:p'`

echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Solicitado scan ao Qualys. O ID do scan é $QUALYS_SCAN_ID. Daqui a $WAIT_SCAN segundos verifico o status."
sleep $WAIT_SCAN

curl -s -u ""$QUALYS_USER:$QUALYS_USER_PASS"" "$QUALYS_URL/qps/rest/3.0/status/was/wasscan/$QUALYS_SCAN_ID" -o $PWD/log/scanStatusCheck.log > /dev/null 2>&1
SCAN_STATUS=`cat $PWD/log/scanStatusCheck.log | sed -n 's:.*<status>\(.*\)</status>.*:\1:p'`

		while [ "$SCAN_STATUS" != "FINISHED" ] 
		do
			echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Que pena. O scan $QUALYS_SCAN_ID está com status $SCAN_STATUS, portanto temos que aguardar. Daqui a $WAIT_SCAN segundos verifico novamente! ;-)"

			sleep $WAIT_SCAN

			curl -u ""$QUALYS_USER:$QUALYS_USER_PASS"" "$QUALYS_URL/qps/rest/3.0/status/was/wasscan/$QUALYS_SCAN_ID" -o $PWD/log/scanStatusCheck.log > /dev/null 2>&1

			SCAN_STATUS=`cat $PWD/log/scanStatusCheck.log | sed -n 's:.*<status>\(.*\)</status>.*:\1:p'`
		done

		# Cria XML para conefeccão do relatório
		echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | O scan $QUALYS_SCAN_ID finalizou, estou desenhando o relatório."
		cat <<EOF > $PWD/xml/wasreport.xml
		<ServiceRequest>
		   <data>
		      <Report>
			 <name>$QUALYS_PROJECT_NAME $QUALYS_SCAN_ID $TIME_SCAN</name>
			 <description>$QUALYS_PROJECT_NAME $QUALYS_SCAN_ID $TIME_SCAN</description>
			 <format>PDF_ENCRYPTED</format>
			 <password>$QUALYS_REPORT_PASS</password>
			 <type>WAS_SCAN_REPORT</type>
			 <config>
			    <scanReport>
			       <target>
				  <scans>
				     <WasScan>
				        <id>$QUALYS_SCAN_ID</id>
				     </WasScan>
				  </scans>
			       </target>
			       <display>
				  <contents>
				     <ScanReportContent>DESCRIPTION</ScanReportContent>
				     <ScanReportContent>SUMMARY</ScanReportContent>
				     <ScanReportContent>GRAPHS</ScanReportContent>
				     <ScanReportContent>RESULTS</ScanReportContent>
				     <ScanReportContent>INDIVIDUAL_RECORDS</ScanReportContent>
				     <ScanReportContent>RECORD_DETAILS</ScanReportContent>
				     <ScanReportContent>ALL_RESULTS</ScanReportContent>
				     <ScanReportContent>APPENDIX</ScanReportContent>
				  </contents>
				  <graphs>
				     <ScanReportGraph>VULNERABILITIES_BY_SEVERITY</ScanReportGraph>
				     <ScanReportGraph>VULNERABILITIES_BY_OWASP</ScanReportGraph>
				     <ScanReportGraph>VULNERABILITIES_BY_WASC</ScanReportGraph>
				     <ScanReportGraph>VULNERABILITIES_BY_WASC</ScanReportGraph>
				     <ScanReportGraph>SENSITIVE_CONTENTS_BY_GROUP</ScanReportGraph>
				  </graphs>
				  <groups>
				     <ScanReportGroup>GROUP</ScanReportGroup>
				     <ScanReportGroup>STATUS</ScanReportGroup>
				     <ScanReportGroup>QID</ScanReportGroup>
				  </groups>
				  <options>
				     <rawLevels>true</rawLevels>
				  </options>
			       </display>
			    </scanReport>
			 </config>
		      </Report>
		   </data>
		</ServiceRequest>
EOF

#Chama API para criação do relatório utilizando padrão criado no XML anterior
echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Solicitando relatório."
curl -s -u ""$QUALYS_USER:$QUALYS_USER_PASS"" -H "content-type: text/xml" -X "POST" --data-binary @- "$QUALYS_URL/qps/rest/3.0/create/was/report" -o $PWD/log/lastReportRequest.log < $PWD/xml/wasreport.xml 

#Guarda o ID de request do último relatório
QUALYS_REPORT_ID=`cat $PWD/log/lastReportRequest.log | sed -n 's:.*<id>\(.*\)</id>.*:\1:p'`

echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Solicitado relatório do scan $QUALYS_SCAN_ID. O ID do relatório é $QUALYS_REPORT_ID. Daqui a $WAIT_REPORT segundos verifico o status."

sleep $WAIT_REPORT

#Verifica status do último relatório
curl -s -u ""$QUALYS_USER:$QUALYS_USER_PASS"" "$QUALYS_URL/qps/rest/3.0/status/was/report/$QUALYS_REPORT_ID" -o $PWD/log/lastReportStatus.log > /dev/null 2>&1


#Obtem o status de término do relatório 
QUALYS_REPORT_STATUS=`cat $PWD/log/lastReportStatus.log | sed -n 's:.*<status>\(.*\)</status>.*:\1:p'`

			while [ "$QUALYS_REPORT_STATUS" != "COMPLETE" ] 
			do

				echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME |  Que pena. A construção do relatório $QUALYS_REPORT_ID está com status $QUALYS_REPORT_STATUS, temos que aguardar. Daqui a $WAIT_REPORT segundos verifico novamente! ;-)"
				sleep $WAIT_REPORT
				
				#Verifica status do último relatório
				curl -s -u ""$QUALYS_USER:$QUALYS_USER_PASS"" "$QUALYS_URL/qps/rest/3.0/status/was/report/$QUALYS_REPORT_ID" -o $PWD/log/lastReportStatus.log > /dev/null 2>&1

				#Obtem o status de término do relatório 
				QUALYS_REPORT_STATUS=`cat $PWD/log/lastReportStatus.log | sed -n 's:.*<status>\(.*\)</status>.*:\1:p'`
			
			done

echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | O relatório $QUALYS_REPORT_ID está pronto! Estou enviando neste momento por e-mail! =)"

				#Cria XML com informações de envio. DEVE-SE PREENCHER A LISTA DE TODOS OS EMAIL A SEREM ENVIADOS
				cat <<EOF > $PWD/xml/wasEmail.xml
				<ServiceRequest>
				<data>
				<Report>
				<distributionList>
				<add>
				<EmailAddress><![CDATA[eklzjdhi@sharklasers.com]]></EmailAddress>
				</add>
				</distributionList>
				</Report>
				</data>
				</ServiceRequest>
EOF


#Realiza chamada para envio do realatório				
echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Chamando API de envio de e-mail."

curl -s -u ""$QUALYS_USER:$QUALYS_USER_PASS"" -H "content-type: text/xml" -X "POST" --data-binary @- "$QUALYS_URL/qps/rest/3.0/send/was/report/$QUALYS_REPORT_ID" -o log/wasemail.log < $PWD/xml/wasEmail.xml

echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Relatório $QUALYS_REPORT_ID foi enviado para os seguintes e-mails: $(cat $PWD/xml/wasEmail.xml | grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" | tr "\n" ", ")."
echo "$(date "+%Y-%m-%d %H:%M:%S") | $QUALYS_PROJECT_NAME | Good luck, dude!"
#FIM