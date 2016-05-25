////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	AddressForum = Catalogs.InformationReferencesForForms.Forum.Address;
	
	Items.GroupFooter.Visible = Not IsBlankString(AddressForum);
	
	SetPrivilegedMode(True);
	UserID = Users.CurrentUser().ServiceUserID;
	SetPrivilegedMode(False);
	
	Result = GetListOrder();
	If Result = Undefined Then 
		Return;
	EndIf;
	
	ShowForm = True;
	
	CreatePageElements(Result);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ShowForm Then 
		
		If Not IsBlankString(AddressForum) Then 
			GotoURL(AddressForum);
		EndIf;
		
		Cancel = True;
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure ClickOnThemeWithNewComments(Item)
	
	Filter = New Structure("FormItemName", Item.Name);
	FoundStrings = TableForNewComments.FindRows(Filter);
	If FoundStrings.Count() = 0 Then 
		Return;
	EndIf;
	
	SubjectAddress = FoundStrings.Get(0).Address;
	
	GotoURL(SubjectAddress);
	
EndProcedure

&AtClient
Procedure ClickOnNewTopic(Item)
	
	Filter = New Structure("FormItemName", Item.Name);
	FoundStrings = TableForNewTopics.FindRows(Filter);
	If FoundStrings.Count() = 0 Then 
		Return;
	EndIf;
	
	SubjectAddress = FoundStrings.Get(0).Address;
	
	GotoURL(SubjectAddress);
	
EndProcedure

&AtClient
Procedure ForumLabelClick(Item)
	
	If Not IsBlankString(AddressForum) Then 
		GotoURL(AddressForum);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Function GetListOrder()
	
	Try
		Proxy = InformationCenterServer.GetProxyManagementConference();
		Return Proxy.getForumTopics(String(UserID));
	Except
		EventName = InformationCenterServer.GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
EndFunction

&AtServer
Procedure CreatePageElements(Result)
	
	If Result.commentTopics.topicDescriptionCollection.Count() <> 0 Then 
		GenerateItemsNewComments(Result.commentTopics.topicDescriptionCollection);
	EndIf;
	
	If Result.mainTopics.topicDescriptionCollection.Count() <> 0 Then
		GenerateNewItemsOrder(Result.mainTopics.topicDescriptionCollection);
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateItemsNewComments(NewComments)
	
	SubjectTemplateWithNewComments = "%1 (%2)";
	
	Iteration = 0;
	For Each Comment IN NewComments Do 
		
		NewItemName                     = "SubjectWithNewComments" + String(Iteration);
		NewItem                          = Items.Add(NewItemName, Type("FormDecoration"), Items.NewComments);
		NewItem.Type                      = FormDecorationType.Label;
		NewItem.Title                = StringFunctionsClientServer.PlaceParametersIntoString(SubjectTemplateWithNewComments, Comment.subject, String(Comment.messageCount));
		NewItem.Hyperlink              = True;
		NewItem.HorizontalStretch = True;
		NewItem.SetAction("Click", "ClickOnThemeWithNewComments");
		
		TableElement                    = TableForNewComments.Add();
		TableElement.FormItemName   = NewItemName;
		TableElement.Address              = Comment.url;
		
		Iteration = Iteration + 1;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateNewItemsOrder(NewTopics)
	
	Iteration = 0;
	For Each Subject IN NewTopics Do 
		
		ElementNameGroupsNewTheme          = "NewTopicGroup" + String(Iteration);
		NewTopicGroup                     = Items.Add(ElementNameGroupsNewTheme, Type("FormGroup"), Items.NewTopics);
		NewTopicGroup.Type                 = FormGroupType.UsualGroup;
		NewTopicGroup.ShowTitle = False;
		NewTopicGroup.Group         = ChildFormItemsGroup.Horizontal;
		NewTopicGroup.Representation         = ?(Iteration = 0, UsualGroupRepresentation.None, ServiceTechnologyIntegrationWithSSL.CommonGroupLineDisplaying());
		
		ElementNameNewTheme                      = "NewSubject" + String(Iteration);
		ItemNewTheme                          = Items.Add(ElementNameNewTheme, Type("FormDecoration"), NewTopicGroup);
		ItemNewTheme.Type                      = FormDecorationType.Label;
		ItemNewTheme.Title                = Subject.subject;
		ItemNewTheme.Hyperlink              = True;
		ItemNewTheme.HorizontalStretch = True;
		ItemNewTheme.SetAction("Click", "ClickOnNewTopic");
		
		ElementNameSubject                      = "Subject" + String(Iteration);
		SubjectItem                          = Items.Add(ElementNameSubject, Type("FormDecoration"), NewTopicGroup);
		SubjectItem.Type                      = FormDecorationType.Label;
		SubjectItem.Title                = Subject.topicName;
		SubjectItem.HorizontalStretch = True;
		SubjectItem.HorizontalAlign  = ItemHorizontalLocation.Right;
		
		TableElement                    = TableForNewTopics.Add();
		TableElement.FormItemName   = ElementNameNewTheme;
		TableElement.Address              = Subject.url;
		
		Iteration = Iteration + 1;
		
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
