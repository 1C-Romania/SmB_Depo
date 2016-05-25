////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("OpenAllMessages") Then
		OpenAllMessages();
	ElsIf Parameters.Property("OpenNews") Then
		If Parameters.Property("ID") Then 
			OpenNews(Parameters.ID);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ClickingOnNews(Item)
	
	Filter = New Structure;
	Filter.Insert("FormItemName", Item.Name);
	
	RowArray = AllNewsTable.FindRows(Filter);
	If RowArray.Count() = 0 Then 
		Return;
	EndIf;
	
	CurrentMessage = RowArray.Get(0);
	
	If CurrentMessage.InformationType = "Inaccessibility" Then 
		
		OpenNews(CurrentMessage.ID);
		
	ElsIf CurrentMessage.InformationType = "NotificationOfRequest" Then 
		
		IdeaIdentifier = String(CurrentMessage.ID);
		
		InformationCenterClient.ShowIdea(IdeaIdentifier);
		
	EndIf;

	
EndProcedure

&AtClient
Procedure AllMessageClick(Item)
	
	Close();
	InformationCenterClient.ShowAllMessage();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure OpenAllMessages()
	
	Title = NStr("en = 'Messages'");
	GenerateAllNewsList();
	Items.CommonGroup.CurrentPage = Items.GroupNews;
	
EndProcedure

&AtServer
Procedure OpenNews(ID)
	
	Items.CommonGroup.CurrentPage = Items.GroupNews;
	SetPrivilegedMode(True);
	RefToData	= Catalogs.InformationCenterCommonData.FindByAttribute("ID", ID);
	If RefToData.IsEmpty() Then 
		Return;
	EndIf;
		
	Title = RefToData.Description;
	
	Attachments  = RefToData.Attachments.Get();
	HTMLText = RefToData.HTMLText;
	
	If TypeOf(Attachments) = Type("Structure") Then 
		AttachmentsStructure = Attachments;
	Else
		AttachmentsStructure = New Structure;
	EndIf;
	
	Content.SetHTML(HTMLText, AttachmentsStructure);
	
EndProcedure

&AtServer
Procedure GenerateAllNewsList()
	
	AllNewsTable.Clear();
	
	SetPrivilegedMode(True);
	
	ReturnedTable = InformationCenterServer.GenerateAllNewsList();
	
	If ReturnedTable.Count() = 0 Then 
		Return;
	EndIf;
	
	AllNewsTable.Load(ReturnedTable);
	
	GroupNews = Items.GroupAllNews;
	
	For Iteration = 0 To AllNewsTable.Count() - 1 Do
		
		Criticality  = AllNewsTable.Get(Iteration).Criticality;
		Description = AllNewsTable.Get(Iteration).Description;
		Picture     = ?(Criticality > 5, PictureLib.ServiceNotification, PictureLib.MessageService);
		
		GroupNews                     = Items.Add("GroupNews" + String(Iteration), Type("FormGroup"), GroupNews);
		GroupNews.Type                 = FormGroupType.UsualGroup;
		GroupNews.ShowTitle = False;
		GroupNews.Group         = ChildFormItemsGroup.Horizontal;
		GroupNews.Representation         = UsualGroupRepresentation.None;
		
		PictureNews                = Items.Add("PictureNews" + String(Iteration), Type("FormDecoration"), GroupNews);
		PictureNews.Type            = FormDecorationType.Picture;
		PictureNews.Picture       = Picture;
		PictureNews.Width         = 2;
		PictureNews.Height         = 1;
		PictureNews.PictureSize = PictureSize.Stretch;
		
		NewsName                          = Items.Add("NewsName" + String(Iteration), Type("FormDecoration"), GroupNews);
		NewsName.Type                      = FormDecorationType.Label;
		NewsName.Title                = Description;
		NewsName.HorizontalStretch = True;
		NewsName.VerticalAlign    = ItemVerticalAlign.Center;
		NewsName.TitleHeight          = 1;
		NewsName.Hyperlink	            = True;
		NewsName.SetAction("Click", "ClickingOnNews");
		
		If Criticality = 10 Then 
			NewsName.Font = New Font(, , True, , , );
		EndIf;
		
		AllNewsTable.Get(Iteration).FormItemName = "NewsName" + String(Iteration);
	
	EndDo;
	
EndProcedure










// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
