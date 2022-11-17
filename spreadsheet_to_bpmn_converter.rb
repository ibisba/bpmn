require 'nokogiri'

class SpreadsheetToBPMNConverter
  def check_name (c)
    t = c.text()
    converted = t.gsub(/\W/, '-')
    return converted
  end
  
  def check_column_indices
    @doc = Nokogiri::XML(File.open(ARGV[0]))
    @sheet = @doc.css('//sheet')
    row_1 = @sheet.at_css('rows/row')
    @investigation_index = row_1.at_css("cell[text() = 'Investigation']")['column']
    @study_index = row_1.at_css("cell[text() = 'Study']")['column']
    @assay_index = row_1.at_css("cell[text() = 'Assay']")['column']
  end
  
  def parse_process
    project = {}
    project['id'] = 'hierarchical-model'
    project['name'] = 'Hierarchical Model'
    project['isExecutable'] = true
    project['investigations'] = []

    check_column_indices
    
    @sheet.css('rows/row').each do |r|
      r.css('cell').each do |c|
        if c['row'] == '1'
          next
        end
        if c['type'] == 'blank'
          next
        end
        if c['column'] == @investigation_index
          @investigation = {}
          @investigation['name'] = check_name(c)
          @investigation['studies'] = []
          project['investigations'] << @investigation
          @study = nil
        end
        if c['column'] == @study_index
          @study = {}
          @study['name'] = check_name(c)
          @study['assays'] = []
          if !@investigation
            puts 'Investigation is null'
          end
          @investigation['studies'] << @study
        end
        if c['column'] == @assay_index
          @assay = {}
          @assay['name'] = check_name(c)
          @study['assays'] << @assay
        end
      end
    end
    @project = project
  end
  
  def build

    parse_process
    
    Nokogiri::XML::Builder.new do |xml|
      @xml = xml
      @definitions = @xml.definitions('xmlns' => 'http://www.omg.org/spec/BPMN/20100524/MODEL',
                                     'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                     'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                                     'xmlns:flowable' => 'http://flowable.org/bpmn',
                                     'xmlns:bpmndi' => 'http://www.omg.org/spec/BPMN/20100524/DI',
                                     'xmlns:omgdc' => 'http://www.omg.org/spec/DD/20100524/DC',
                                     'xmlns:omgdi' => 'http://www.omg.org/spec/DD/20100524/DI',
                                      'targetNamespace' => '') do
        process = @xml.process do
          linkStart = xml.startEvent
          linkStart['id'] = @project['id'] + '-Start'
          @p_link_source = linkStart['id']
          next_i = 1
          @project['investigations'].each do |i|

            investigation = @xml.subProcess do
              sLinkStart = xml.startEvent
              sLinkStart['id'] = 'I' + next_i.to_s + '-Start'
              @s_link_source = sLinkStart['id']

              next_s = 1
              i['studies'].each do |s|
                study = @xml.subProcess do
                  aLinkStart = xml.startEvent
                  aLinkStart['id'] = 'I' + next_i.to_s + '-S' + next_s.to_s + '-Start'
                  @a_link_source = aLinkStart['id']

                  next_a = 1
                  s['assays'].each do |a|
                    assay = @xml.userTask
                    assay['id'] = 'I' + next_i.to_s + '-S' + next_s.to_s + '-A' + next_a.to_s
                    next_a = next_a + 1
                    assay['name'] = a['name']
                    assay['flowable:assignee'] = 'admin'
                    assay['flowable:formFieldValidation'] = 'true'

                    flow = @xml.sequenceFlow
                    flow['sourceRef'] = @a_link_source
                    flow['targetRef'] = assay['id']
                    flow['id'] = flow['sourceRef'] + '-to-' + flow['targetRef']
                    @a_link_source = assay['id']

                  end
                  linkEnd = xml.endEvent
                  linkEnd['id'] =  + 'I' + next_i.to_s + '-S' + next_s.to_s + '-end'

                  flow = @xml.sequenceFlow
                  flow['sourceRef'] = @a_link_source
                  flow['targetRef'] = linkEnd['id']
                  flow['id'] = flow['sourceRef'] + '-to-' + flow['targetRef']
                end
                study['id'] = 'I' + next_i.to_s + '-S' + next_s.to_s
                next_s = next_s + 1
                study['name'] = s['name']

                flow = @xml.sequenceFlow
                flow['sourceRef'] = @s_link_source
                flow['targetRef'] = study['id']
                flow['id'] = flow['sourceRef'] + '-to-' + flow['targetRef']
                @s_link_source = study['id']
              end
              linkEnd = xml.endEvent
              linkEnd['id'] =  + 'I' + next_i.to_s + '-end'

              flow = @xml.sequenceFlow
              flow['sourceRef'] = @s_link_source
              flow['targetRef'] = linkEnd['id']
              flow['id'] = flow['sourceRef'] + '-to-' + flow['targetRef']
            end

            investigation['id'] = 'I' + next_i.to_s
            next_i = next_i + 1
            investigation['name'] = i['name']

            flow = @xml.sequenceFlow
            flow['sourceRef'] = @p_link_source
            flow['targetRef'] = investigation['id']
            flow['id'] = flow['sourceRef'] + '-to-' + flow['targetRef']
            @p_link_source = investigation['id']
          end
          linkEnd = xml.endEvent
          linkEnd['id'] = @project['id'] + '-End'

          flow = @xml.sequenceFlow
          flow['sourceRef'] = @p_link_source
          flow['targetRef'] = linkEnd['id']
          flow['id'] = flow['sourceRef'] + '-to-' + flow['targetRef']

        end
        process['id'] = @project['id']
        process['name'] =" Hierarchical Model"
        process['isExecutable'] ="true"
      end
    end

  end

end

bpmn = SpreadsheetToBPMNConverter.new().build

File.open("#{File.dirname(ARGV[0])}/#{File.basename(ARGV[0],'.*')}.bpmn", "w") { |f| f.write bpmn.to_xml.to_s }

# File.write ("simple.bpmn", bpmn.to_xml.to_s)
