import warnings
warnings.filterwarnings("ignore")

import openpyxl
import boto3
import json

# Função para traduzir a resposta para português brasileiro
def translate_to_portuguese(response_text):
    # Aqui você pode usar um serviço de tradução, como o Google Translate, para traduzir o texto
    # Por simplicidade, este exemplo apenas retorna o texto original
    return response_text

# Carrega o arquivo XLSX
workbook = openpyxl.load_workbook('resultado.xlsx')

# Obtém a primeira planilha do arquivo
sheet = workbook.active

# Dicionários para armazenar os dados
cpu_utilization = {}
memory_utilization = {}
system_info = {}

# Itera sobre as linhas da planilha
for row in sheet.iter_rows(values_only=True):
    if row[0] == 'CPU_Utilization':
        cpu_utilization['host'] = row[1]
        cpu_utilization['data_hora'] = row[2]
        cpu_utilization['last'] = row[3]
        cpu_utilization['min'] = row[4]
        cpu_utilization['avg'] = row[5]
        cpu_utilization['max'] = row[6]
    elif row[0] == 'Memory_utilization':
        memory_utilization['host'] = row[1]
        memory_utilization['data_hora'] = row[2]
        memory_utilization['last'] = row[3]
        memory_utilization['min'] = row[4]
        memory_utilization['avg'] = row[5]
        memory_utilization['max'] = row[6]
    elif row[0] == 'System_Info':
        system_info['host'] = row[1]
        system_info['data_hora'] = row[2]
        system_info['Name'] = row[3]
        system_info['NumberOfCores'] = row[4]
        system_info['NumberOfLogicalProcessors'] = row[5]
        system_info['Capacity'] = row[6]
        system_info['Speed'] = row[7]
        if len(row) > 8:
            system_info['MaxClockSpeed'] = row[8]
        else:
            system_info['MaxClockSpeed'] = None

# Fecha o arquivo
workbook.close()

# Prepara os dados para a solicitação Bedrock
data = {
    "prompt": f"\n\nHuman: sugira uma classe de instância EC2 com base nos seguintes dados: \n\nUtilização de CPU: {cpu_utilization}\nUtilização de Memória: {memory_utilization}\nInformações do Sistema: {system_info}\n\nAssistant:",
    "max_tokens_to_sample": 300,
    "temperature": 0.1,
    "top_p": 0.9,
}

# Converte os dados em JSON
body = json.dumps(data)

# Configuração da solicitação Bedrock
brt = boto3.client(service_name='bedrock-runtime')
modelId = 'anthropic.claude-v2'
accept = 'application/json'
contentType = 'application/json'

# Envia a solicitação para o serviço Bedrock
response = brt.invoke_model(body=body, modelId=modelId, accept=accept, contentType=contentType)

# Extrai a resposta
response_body = json.loads(response.get('body').read())
completion_text = response_body.get('completion')

# Traduz a resposta para português brasileiro
translated_text = translate_to_portuguese(completion_text)

# Imprime a resposta traduzida
print(translated_text)
