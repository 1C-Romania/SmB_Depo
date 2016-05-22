////////////////////////////////////////////////////////////////////////////////
// Subsystem "Information center".
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Opens a display form of a separate news.
//
// Parameters:
//  ID - UUID - news identifier.
//
Procedure ShowNews(ID) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("OpenNews");
	FormParameters.Insert("ID", ID);
	OpenForm("DataProcessor.InformationCenter.Form.ShowingMessages", FormParameters);
	
EndProcedure

// Opens a display form of all news.
//
//
Procedure ShowAllMessage() Export
	
	FormParameters = New Structure("OpenAllMessages");
	OpenForm("DataProcessor.InformationCenter.Form.ShowingMessages", FormParameters);
	
EndProcedure

// Procedure-handler on clicking an info reference.
//
// Parameters:
//  Form - ManagedForm - managed form context.
//  Item - FormItem - form group.
//
Procedure ClickOnInformationLink(Form, Item) Export
	
	Hyperlink = Form.InformationReferences.FindByValue(Item.Name);
	
	If Hyperlink <> Undefined Then
		
		GotoURL(Hyperlink.Presentation);
		
	EndIf;
	
EndProcedure

// Procedure-handler on clicking all info refs.
//
// Parameters:
//  PathToForm - String - full path to a form.
//
Procedure ReferenceClickAllInformationLinks(PathToForm) Export
	
	FormParameters = New Structure("PathToForm", PathToForm);
	OpenForm("DataProcessor.InformationCenter.Form.InformationalRefsInContext", FormParameters);
	
EndProcedure

// Opens a form with the feedback content.
//
// DesireID - String - unique feedback identifier.
//
Procedure ShowIdea(Val IdeaIdentifier) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("IdeaIdentifier", IdeaIdentifier);
	FormParameters.Insert("CurrentCommentsPage", 1);
	OpenForm("DataProcessor.InformationCenter.Form.Idea", FormParameters, , New UUID);
	
EndProcedure

// Opens a form with the Idea center.
//
Procedure OpenIdeasCenter() Export 
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentIdeasFilter", "voiting");
	FormParameters.Insert("CurrentSorting", "CreateDate");
	FormParameters.Insert("CurrentPage", 1);
	OpenForm("DataProcessor.InformationCenter.Form.IdeaCenter", FormParameters, , New UUID);
	
EndProcedure

// Opens a form with all support requests.
//
Procedure OpenRequestsToSupport() Export 
	
	OpenForm("DataProcessor.InformationCenter.Form.SupportServiceRequests", , , New UUID);
	
EndProcedure

// Opens a form to send a message to the recipient.
//
// Parameters:
// CreateSupportRequests - Boolean - whether create a support request or not.
//
Procedure OpenFormOpeningMessagesToSupport(CreateReference, SupportRequestID = Undefined) Export
	
	MessageParameters = New Structure;
	MessageParameters.Insert("CreateReference", CreateReference);
	If SupportRequestID <> Undefined Then 
		MessageParameters.Insert("SupportRequestID", SupportRequestID);
	EndIf;
	OpenForm("DataProcessor.InformationCenter.Form.SendingMessageToSupportService", MessageParameters);
	
EndProcedure

// Opens the support request form.
//
// Parameters:
//  SupportRequestID - UUID - support request identifier.
//
Procedure OpenContactSupport(SupportRequestID) Export
	
	SupportRequestParameters = New Structure;
	SupportRequestParameters.Insert("SupportRequestID", SupportRequestID);
	OpenForm("DataProcessor.InformationCenter.Form.InteractionsOnInquiry", SupportRequestParameters, , New UUID);
	
EndProcedure

// Opens support request interaction.
//
// Parameters:
//  SupportRequestID - UUID - support request identifier.
//  InteractionsIdentifier - UUID - interaction identifier.
//  TypeInteractions - String - interaction type.
//  Incoming - Boolean - flag: incoming message or not.
//  Seen - Boolean - flag: a message is seen or not.
//
Procedure OpenInteractionToSupport(SupportRequestID, InteractionsIdentifier, TypeInteractions, Incoming, Seen = True) Export 
	
	InteractionParameters = New Structure;
	InteractionParameters.Insert("SupportRequestID", SupportRequestID);
	InteractionParameters.Insert("InteractionsIdentifier", InteractionsIdentifier);
	InteractionParameters.Insert("TypeInteractions", TypeInteractions);
	InteractionParameters.Insert("Incoming", Incoming);
	InteractionParameters.Insert("Seen", Seen);
	OpenForm("DataProcessor.InformationCenter.Form.InteractionOnSupportRequest", InteractionParameters);
	
EndProcedure

// Opens unseen interaction.
//
// Parameters:
//  SupportRequestID - UUID - support request identifier.
//  ListNotSeenInteractions - ValueList - list of unseen interaction.
//
Procedure OpenNotSeenInteractions(SupportRequestID, ListNotSeenInteractions) Export 
	
	If ListNotSeenInteractions.Count() = 1 Then 
		FirstInteraction = ListNotSeenInteractions.Get(0).Value;
		OpenInteractionToSupport(SupportRequestID, FirstInteraction.ID, FirstInteraction.Type, FirstInteraction.Incoming, False);
	Else
		Parameters = New Structure;
		Parameters.Insert("ListNotSeenInteractions", ListNotSeenInteractions);
		Parameters.Insert("SupportRequestID", SupportRequestID);
		OpenForm("DataProcessor.InformationCenter.Form.NotSeenInteractions", Parameters, , New UUID);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAM INTERFACE (OLD)

// Opens a form to send a message to the recipient.
//
Procedure OpenSendingMessageToSupportForm(MessageParameters = Undefined) Export
	
	OpenForm("DataProcessor.InformationCenter.Form.DeleteSendingMessageToSupport", MessageParameters);
	
EndProcedure

// Returns a size in megabytes, attachment size is not larger than 20 megabytes.
//
// Returns:
// Number - attachment size in megabytes.
//
Function AttachmentsMaximumSizeForSendingMessageToServiceSupport() Export
	
	Return 20;
	
EndFunction



