require 'rest-client'
require 'base64'
require 'json'

class RunModel
  def upload_bpmn(bpmn_file)
    deployment = RestClient::Request.execute(url: 'http://localhost/flowable-ui/process-api/repository/deployments',
                                             method: :post,
                                             headers:{Authorization: "Basic #{Base64.encode64('admin:test')}"},
                                             :payload => {
                                               :multipart => true,
                                               :file => File.new(bpmn_file, 'r')
                                             })

    id = JSON.parse(deployment)['id']
    url = "http://localhost/flowable-ui/process-api/repository/process-definitions"
    definitions = RestClient::Request.execute(url: url,
                                              method: :get,
                                              headers:{Authorization: "Basic #{Base64.encode64('admin:test')}",
                                                       accept: :json,
                                                       params: {'deploymentId' => id}})
    definition_id = JSON.parse(definitions)['data'][0]['id']

    to_send = { "processDefinitionId" => definition_id}

    running = RestClient.post('http://localhost/flowable-ui/process-api/runtime/process-instances',
                              to_send.to_json,
                              {Authorization: "Basic #{Base64.encode64('admin:test')}",
                               content_type: :json,
                               accept: :json})
    puts running
                                           
  end
  
end

rm = RunModel.new().upload_bpmn(ARGV[0])


