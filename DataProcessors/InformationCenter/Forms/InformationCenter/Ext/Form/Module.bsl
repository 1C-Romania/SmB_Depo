////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ServiceTechnologyIntegrationWithSSL.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	UseSeparationByDataAreas = ServiceTechnologyIntegrationWithSSL.DataSeparationEnabled()
		AND ServiceTechnologyIntegrationWithSSL.CanUseSeparatedData();
	
	InformationSearchReference = "http://v8.1c.ru/search/";
	
	If UseSeparationByDataAreas Then // for service model
		
		// Home page
		MainPage                     = Catalogs.InformationReferencesForForms.HomePage;
		HomePage                    = New Structure("Name, Address", MainPage.Description, MainPage.Address);
		Items.HomePage.Title = HomePage.Name;
		Items.HomePage.Visible = ?(IsBlankString(HomePage.Address), False, True);
		
		InformationCenterServerOverridable.DefineInformationSearchReference(InformationSearchReference);
		
		GenerateNewsList();
		
		IntegrationWithSupportServiceIsSet = InformationCenterServer.IntegrationWithSupportServiceIsSet();
		
	Else // for the local mode
		
		Items.GroupOfStartingPages1.Visible    = False;
		Items.GroupInteractions.Visible      = False;
		
	EndIf;
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences, 1, 10, False);
	
	ServiceTechnologyIntegrationWithSSL.IntegrationWith1CBuhphoneOnCreateAtServer(Items.CommonCommandRun1CBuhphone);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ClickingOnNews(Item)
	
	Filter = New Structure;
	Filter.Insert("FormItemName", Item.Name);
	
	RowArray = NewsTable.FindRows(Filter);
	If RowArray.Count() = 0 Then 
		Return;
	EndIf;
	
	CurrentMessage = RowArray.Get(0);
	
	If CurrentMessage.InformationType = "Inaccessibility" Then 
		
		ID = CurrentMessage.ID;
		ExternalRef = CurrentMessage.ExternalRef;
		
		If Not IsBlankString(ExternalRef) Then 
			GotoURL(ExternalRef);
			Return;
		EndIf;
		
		InformationCenterClient.ShowNews(ID);
		
	ElsIf CurrentMessage.InformationType = "NotificationOfRequest" Then 
		
		IdeaIdentifier = String(CurrentMessage.ID);
		
		InformationCenterClient.ShowIdea(IdeaIdentifier);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClickMoreMessages(Item)
	
	InformationCenterClient.ShowAllMessage();
	
EndProcedure

&AtClient
Procedure InquiriesToSupportClick(Item)
	
	If IntegrationWithSupportServiceIsSet Then 
		InformationCenterClient.OpenRequestsToSupport();
	Else
		OpenForm("DataProcessor.InformationCenter.Form.DeleteUserSupportRequests");
	EndIf;
	
EndProcedure

&AtClient
Procedure IdeaCenterClick(Item)
	
	InformationCenterClient.OpenIdeasCenter();
	
EndProcedure

&AtClient
Procedure HomePageClick(Item)
	
	If Not HomePage.Property("Address") Then 
		Return;
	EndIf;
	
	GotoURL(HomePage.Address);
	
EndProcedure

&AtClient
Procedure ClickForum(Item)
	
	OpenForm("DataProcessor.InformationCenter.Form.DiscussOnForum");
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure FindAnswerOnQuestion(Command)
	
	SearchForAnswerOnQuestion();
	
EndProcedure

&AtClient
Procedure Attachable_ClickOnInformationLink(Command)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Command);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure GenerateNewsList()
	
	SetPrivilegedMode(True);
	InformationCenterServer.GenerateNewsListToDesktop(NewsTable);
	
	If NewsTable.Count() = 0 Then 
		Return;
	EndIf;
	
	GroupNews = Items.GroupNews;
	
	For Iteration = 0 To NewsTable.Count() - 1 Do
		
		Description = NewsTable.Get(Iteration).RefToData.Description;
		
		If IsBlankString(Description) Then 
			Continue;
		EndIf;
		
		Criticality  = NewsTable.Get(Iteration).RefToData.Criticality;
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
		NewsName.Hyperlink              = True;
		NewsName.SetAction("Click", "ClickingOnNews");
		
		NewsTable.Get(Iteration).FormItemName = NewsName.Name;
		NewsTable.Get(Iteration).InformationType    = NewsTable.Get(Iteration).RefToData.InformationType.Description;
		NewsTable.Get(Iteration).ID    = NewsTable.Get(Iteration).RefToData.ID;
		NewsTable.Get(Iteration).ExternalRef    = NewsTable.Get(Iteration).RefToData.ExternalRef;
		
	EndDo;
	
	MoreMessages                          = Items.Add("MoreMessages", Type("FormDecoration"), GroupNews);
	MoreMessages.Type                      = FormDecorationType.Label;
	MoreMessages.Title                = NStr("en = 'More messages'");
	MoreMessages.HorizontalStretch = True;
	MoreMessages.VerticalAlign    = ItemVerticalAlign.Center;
	MoreMessages.Hyperlink              = True;
	MoreMessages.SetAction("Click", "ClickMoreMessages");
	
EndProcedure

&AtClient
Procedure SearchForAnswerOnQuestion()
	
	AttachIdleHandler("IdleProcessingOfFindingAnswerToQuestion", 0.1, True);
	
EndProcedure

&AtClient
Procedure IdleProcessingOfFindingAnswerToQuestion()
	
	If IsBlankString(SearchString) Then
		Return;
	EndIf;
	
	GotoURL(InformationSearchReference + SearchString);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	ServiceTechnologyIntegrationWithSSLClient.IntegrationWith1CBuhphoneClientNotificationProcessing(EventName, Items.CommonCommandRun1CBuhphone);
	
EndProcedure
