require 'rubygems'
require 'indextank'

class Search
  attr_reader :index
  
  def initialize
    # Obtain an IndexTank client
    #client = IndexTank::Client.new('http://:tdw5J7JOLUBIfL@qbb1.api.indextank.com') #parlydata  
    @client = IndexTank::Client.new('http://:wlvpmNrRn4QvXS@dab3a.api.indextank.com') #chocolate-teapot-57
    #client = IndexTank::Client.new('http://:gNlraGxIqHGTsN@dh8iq.api.indextank.com') #parlydata-admin ($50)
    @index = @client.indexes('idx')
  end
  
  def clear_index
    index.document("lords_1").delete
    index.document("commons_1").delete
  end

  def build_index        
    # Add documents to the index
    index.document("lords_1").add(
      {:title => "General Election: International Observers",
      :text => "Lord Greaves asked Her Majesty's Government:
        What arrangements will be made for the appointment of international observers during the next general election campaign.
        The Parliamentary Under-Secretary of State, Department for Constitutional Affairs (Baroness Ashton of apholland) My Lords, it has not been the practice of the UK Government formally to appoint observers at UK elections, However, we are aware that observers, for example, from the Organisation for Security and Co-operation in Europe, have been invited to be present to observe previous election campaigns in the past. We intend to extend a similar invitation when the next election is called.
        Lord Greaves My Lords, I thank the Minister for that fairly helpful Answer—perhaps a very helpful Answer. In considering advice that might be given to the OSCE and any other observers, will the Minister bear in mind the dramatic increases in the number of complaints and allegations about voting fraud, particularly but not only connected with postal voting, which have been made in the past few years?
        Is the noble Baroness aware that only a fortnight ago a former councillor in Blackburn pleaded guilty at Preston Crown Court to such offences in 2002; and that this is only the tip of the iceberg of what is going on? Will she give advice to such observers that they might concentrate their attention on those places and in those areas where such allegations are made?
        Baroness Ashton of Upholland My Lords, I am not sure it is for me to give advice to observers. I think it is for the observers to determine where best they can use their skills and expertise and to look at the elections. There is no evidence of widespread postal voting fraud or that postal voting is inherently less secure. We have cases that are currently sub judice. When they are resolved, we will of course examine any issues that arise because it is important to protect the integrity of all our voting systems.
        Lord Campbell-Savours My Lords, is there not a case for welcoming observers from the emerging democracies, such as Iraq, who have a lot to learn in Britain?
        Baroness Ashton of Upholland My Lords, indeed. We have a good track record in the UK of observers going out to other countries. I think it is absolutely right and proper that we should invite people to observe how we proceed here.
        Lord Cope of Berkeley My Lords, the Minister and the noble Lord, Lord Campbell-Savours, were both thinking of observers coming to learn from us. In the new circumstances, to which the noble Lord, Lord Greaves, draws attention, of the higher possibilities of fraud and so on from the changes, perhaps we have something to learn from other people as well
        ",
        :url => "http://hansard.millbanksystems.com/lords/2005/mar/17/general-election-international-observers",
        :timestamp => Time.parse("2005-05-17").to_i
      }
    )
    index.document("commons_1").add(
      {:title => "Church Rates Bill",
        :keywords => "this, that, the other",
      :text => %Q|MR. PACKE said, it was with great reluctance that he had come to the determination of withdrawing this Bill. He had been led to take that course not at all by any want of confidence in the measure, itself—for he had received from all parts of the kingdom strong testimony in favour of its principles, although there were objections to some of its details—but he had not been able to introduce it until after Easter, having fully believed, from what passed at the commencement of the Session, that the Government would have brought forward a Bill on the subject; and this was the first Wednesday he had been able to fix for the second reading. The late Sir Robert Peel had told Lord John Russell, in 1835, that the question was one of great importance, and that the Session ought not to pass without the introduction of some measure for its settlement. The different Governments have been nineteen years considering what measure to bring in, and there was now no Bill before the House on the subject but what he must call the "Church Destruction Bill" of the hon. Member for the Tower Hamlets (Sir W. Clay). He had reason to hope that the noble Lord the late Member for London, if he had now been in his place, would have supported the principle of the Bill, although he had objected to some of its details, for the noble Lord bad said that the national Church ought to be supported by the nation. If the Bill had gone into Committee, he had intended to strike out all the clauses for the registration of Dissenters, which had been objected to as creating an invidious distinction between Churchmen and Dissenters. The subject was a very difficult one, no doubt, for in the great majority of instances, although conscience was the ostensible, reason, pocket was the real reason why the payment of church rates was objected to. The Session was too far advanced to render it probable that this Bill could be carried through both Houses this year, and he should, therefore, move that the order for the second reading be discharged; but he thought it due to those who had given him their confidence to state that, unless he received a satisfactory assurance from the Government that they would bring in a Bill upon the subject, he should himself introduce a measure on the principle of this at the commencement of the next Session.|,
      :url => "http://hansard.millbanksystems.com/commons/1854/jun/14/church-rates-bill",
      :timestamp => Time.parse("1854-06-14").to_i
      }
    )
  end
  
  def add_facets
    categories = {"house" => "Lords", "source" => "Hansard"}
    index.document("lords_1").update_categories(categories)
    
    categories = {"house" => "Commons", "source" => "Hansard"}
    index.document("commons_1").update_categories(categories)
  end

  def search(query)
    # Search the index
    results = index.search(query, :snippet => 'text', :fetch => ':text, :url, :timestamp')

    print "#{results['matches']} documents found\n"
    results['results'].each { |doc|
      print "docid: #{doc['docid']}\n"
    }
    
    print "\n"
    print "debug: #{results.inspect}"
  end
end