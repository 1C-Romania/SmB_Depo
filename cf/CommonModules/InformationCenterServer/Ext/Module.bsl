////////////////////////////////////////////////////////////////////////////////
// Subsystem "Information center".
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Information references

// Displays info references in a form.
//
// Parameters:
// Form - ManagedForm - form context.
// FormGroup - FormItem - group of a form in which info references are displayed.
// GroupCount - Number - number of info references groups in a form.
// RefsCountInGroup - Number - number of info references in a group.
// OutputReferenceAll - Boolean - show or not reference "All".
// PathToForm - String - full path to the form
//
Procedure OutputContextReferences(Form, FormGroup, GroupCount = 3, RefsCountInGroup = 1, OutputReferenceAll = True, PathToForm = "") Export
	
	Try
		
		If IsBlankString(PathToForm) Then 
			PathToForm = Form.FormName;
		EndIf;
		
		HashPathsToForm = FullPathToFormHash(PathToForm);
		
		TableOfFormLinks = InformationCenterServerReUse.GetTableInformationLinksForForms(HashPathsToForm);
		If TableOfFormLinks.Count() = 0 Then 
			Return;
		EndIf;
		
		// Changing form parameters
		FormGroup.ShowTitle = False;
		FormGroup.ToolTip   = "";
		FormGroup.Representation = UsualGroupRepresentation.None;
		FormGroup.Group = ChildFormItemsGroup.Horizontal;
		
		// Adding a list of information refs
		AttributeName = "InformationReferences";
		AttributesToAdd = New Array;
		AttributesToAdd.Add(New FormAttribute(AttributeName, New TypeDescription("ValueList")));
		Form.ChangeAttributes(AttributesToAdd);
		
		GenerateOutputGroups(Form, TableOfFormLinks, FormGroup, GroupCount, RefsCountInGroup, OutputReferenceAll);
	Except
		EventName = GetEventNameForEventLogMonitor();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Generates hash of a full path to the form on writing.
//
Procedure FullPathToFormBeforeWriteBeforeWriting(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsBlankString(Source.FullPathToForm) Then 
		Source.Hash = FullPathToFormHash(Source.FullPathToForm);
	EndIf;
	
EndProcedure

// Returns an info reference by identifier.
//
// Parameters:
// ID - String - ref identifier.
//
// Returns:
// Structure with fields:
// 	Key - "Address", value - String - ref address.
// 	Key - "Name", value - String - ref name.
//
Function ContextRefByUUID(ID) Export
	
	ReturnedStructure = New Structure;
	ReturnedStructure.Insert("Address", "");
	ReturnedStructure.Insert("Description", "");
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InformationReferencesForForms.Address AS Address,
	|	InformationReferencesForForms.Description AS Description
	|FROM
	|	Catalog.InformationReferencesForForms AS InformationReferencesForForms
	|WHERE
	|	InformationReferencesForForms.ID = &ID
	|	AND Not InformationReferencesForForms.DeletionMark";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ReturnedStructure.Address = Selection.Address;
		ReturnedStructure.Description = Selection.Description;
		Break;
		
	EndDo;
	
	Return ReturnedStructure;
	
EndFunction

// Returns True if support service integration is set.
//
Function IntegrationWithSupportServiceIsSet() Export
	
	SetPrivilegedMode(True);
	Return Not IsBlankString(Constants.SupportServiceSoftwareInterfaceAddress.Get());
	
EndFunction

// Returns an events log monitor event name.
//
// Returns:
// String - events log monitor name.
//
Function GetEventNameForEventLogMonitor() Export
	
	Return NStr("en='Information center';ru='Информационный центр'", ServiceTechnologyIntegrationWithSSL.MainLanguageCode());
	
EndFunction

// Get conference management proxy.
//
// Returns:
//  WSProxy - conference management proxy.
//
Function GetProxyManagementConference() Export
	
	SetPrivilegedMode(True);
	Address              = Constants.ConferenceManagementAddress.Get() + "/ForumService?wsdl";
	UserName    = Constants.InformationCentreConferenceUserName.Get();
	UserPassword = Constants.InformationCenterConferenceUserPassword.Get();
	SetPrivilegedMode(False);
	
	Proxy = ServiceTechnologyIntegrationWithSSL.WSProxy(Address,
		"http://ws.forum.saas.onec.ru/",
		"ForumIntegrationWSImplService",
		"ForumIntegrationWSImplPort",
		UserName,
		UserPassword);
	
	Return Proxy;
	
EndFunction

// Returns Proxy of Manager service Information center.
//
// Returns:
// WSProxy - Information center proxy.
//
Function GetInformationCenterProxy() Export
	
	If Not ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		Raise(NStr("en='Impossible to connect to the service Manager.';ru='Не возможно подключиться к Менеджеру сервиса.'"));
	EndIf;
	
	ModuleSaaSOperations = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	ServiceManagerAddress = ModuleSaaSOperations.InternalServiceManagerURL();
	
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en='Parameters of connection with the service manager have not been set.';ru='Не установлены параметры связи с менеджером сервиса.'"));
	EndIf;
	
	ServiceAddress       = ServiceManagerAddress + "/ws/ManageInfoCenter?wsdl";
	UserName    = ModuleSaaSOperations.ServiceManagerOfficeUserName();
	UserPassword = ModuleSaaSOperations.ServiceManagerOfficeUserPassword();
	SetPrivilegedMode(False);
	
	InformationCenterProxy = ServiceTechnologyIntegrationWithSSL.WSProxy(ServiceAddress,
															"http://www.1c.ru/SaaS/1.0/WS",
															"ManageInfoCenter", 
															, 
															UserName, 
															UserPassword, 
															7);
	
	Return InformationCenterProxy;
	
EndFunction

// Returns Proxy of Manager service Information center.
//
// Returns:
// WSProxy - Information center proxy.
//
Function GetInformationCenterProxy_1_0_1_1() Export
	
	If Not ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		Raise(NStr("en='Impossible to connect to the service Manager.';ru='Не возможно подключиться к Менеджеру сервиса.'"));
	EndIf;
	
	ModuleSaaSOperations = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	ServiceManagerAddress = ModuleSaaSOperations.InternalServiceManagerURL();
	
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en='Parameters of connection with the service manager have not been set.';ru='Не установлены параметры связи с менеджером сервиса.'"));
	EndIf;
	
	ServiceAddress       = ServiceManagerAddress + "/ws/ManageInfoCenter_1_0_1_1?wsdl";
	UserName    = ModuleSaaSOperations.ServiceManagerOfficeUserName();
	UserPassword = ModuleSaaSOperations.ServiceManagerOfficeUserPassword();
	SetPrivilegedMode(False);
	
	InformationCenterProxy = ServiceTechnologyIntegrationWithSSL.WSProxy(ServiceAddress,
															"http://www.1c.ru/SaaS/1.0/WS",
															"ManageInfoCenter_1_0_1_1", 
															, 
															UserName, 
															UserPassword, 
															7);
	
	Return InformationCenterProxy;
	
EndFunction

// Returns Proxy of Manager service Information center.
//
// Returns:
// WSProxy - Information center proxy.
//
Function GetInformationCenterProxy_1_0_1_2() Export
	
	If Not ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		Raise(NStr("en='Impossible to connect to the service Manager.';ru='Не возможно подключиться к Менеджеру сервиса.'"));
	EndIf;
	
	ModuleSaaSOperations = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	ServiceManagerAddress = ModuleSaaSOperations.InternalServiceManagerURL();
	
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en='Parameters of connection with the service manager have not been set.';ru='Не установлены параметры связи с менеджером сервиса.'"));
	EndIf;
	
	ServiceAddress       = ServiceManagerAddress + "/ws/ManageInfoCenter_1_0_1_2?wsdl";
	UserName    = ModuleSaaSOperations.ServiceManagerOfficeUserName();
	UserPassword = ModuleSaaSOperations.ServiceManagerOfficeUserPassword();
	SetPrivilegedMode(False);
	
	InformationCenterProxy = ServiceTechnologyIntegrationWithSSL.WSProxy(ServiceAddress,
															"http://www.1c.ru/SaaS/1.0/WS",
															"ManageInfoCenter_1_0_1_2", 
															, 
															UserName, 
															UserPassword, 
															7);
	
	Return InformationCenterProxy;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Ideas center

// Returns Proxy of Manager service Information center.
//
// Returns:
//  WSProxy - Information center proxy.
//
Function GetIdeasCenterProxy() Export
	
	If Not ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		Raise(NStr("en='Impossible to connect to the service Manager.';ru='Не возможно подключиться к Менеджеру сервиса.'"));
	EndIf;
	
	ModuleSaaSOperations = ServiceTechnologyIntegrationWithSSL.CommonModule("SaaSOperations");
	
	SetPrivilegedMode(True);
	ServiceManagerAddress = ModuleSaaSOperations.InternalServiceManagerURL();
	
	If Not ValueIsFilled(ServiceManagerAddress) Then
		Raise(NStr("en='Parameters of connection with the service manager have not been set.';ru='Не установлены параметры связи с менеджером сервиса.'"));
	EndIf;
	
	ServiceAddress       = ServiceManagerAddress + "/ws/UsersIdeas_1_0_0_1?wsdl";
	UserName    = ModuleSaaSOperations.ServiceManagerOfficeUserName();
	UserPassword = ModuleSaaSOperations.ServiceManagerOfficeUserPassword();
	
	SetPrivilegedMode(False);
	
	ProxyCenterIdeas = ServiceTechnologyIntegrationWithSSL.WSProxy(ServiceAddress,
															"http://www.1c.ru/1cFresh/InformationCenter/UsersIdeas/1.0.0.1",
															"UsersIdeas_1_0_0_1", 
															, 
															UserName, 
															UserPassword, 
															20);
	
	Return ProxyCenterIdeas;
	
EndFunction

// Returns a number of ideas per page.
//
// Return value:
//  Number - number of ideas.
//
Function IdeasQuantityOnPage() Export
	
	Return 5;
	
EndFunction

// Returns a number of comments to an idea per page.
//
// Return value:
//  Number - number of comments.
//
Function CommentsQuantityToIdeaOnPage() Export
	
	Return 5;
	
EndFunction

// Returns an exception text if idea center is unavailable.
//
// Returns:
//  String - exception text.
//
Function ErrorInformationOutputTextInIdeasCenter() Export 
	
	Return NStr("en='Ideas center is temporarily unavailable.
		|Please try again later.';ru='Центр идей временно не доступен.
		|Пожалуйста, повторите попытку позже.'")
	
EndFunction

// Vote for the idea.
//
// Parameters:
//  WSProxy - WSProxy - WSProxy of ideas center.
//  UserIdentifier - String - user identifier.
//  IdeaIdentifier - String - idea identifier.
//  Voice - Number - number of votes.
//
Procedure VoteForIdea(Val WSProxy, Val UserIdentifier, Val IdeaIdentifier, Val Voice) Export
	
	WSProxy.addVote(IdeaIdentifier, UserIdentifier, Voice);
	
EndProcedure

// Sets a flag of viewed idea.
//
// Parameters:
//  IdeaIdentifier - UUID - idea identifier.
//
Procedure SetIdeaViewSign(Val IdeaIdentifier) Export 
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.SetParameter("ID", IdeaIdentifier);
	Query.Text =
	"SELECT
	|	InformationCenterCommonData.Ref AS Ref
	|FROM
	|	Catalog.InformationCenterCommonData AS InformationCenterCommonData
	|WHERE
	|	InformationCenterCommonData.ID = &ID";
	Result = Query.Execute();
	
	If Result.IsEmpty() Then 
		Return;
	EndIf;
	
	Selection = Result.Select();
	
	While Selection.Next() Do
		Record = InformationRegisters.InformationCenterViewedData.CreateRecordManager();
		Record.User = Users.CurrentUser();
		Record.DataInformationCenter = Selection.Ref;
		Record.Viewed = True;
		Record.Write();
	EndDo;
	
EndProcedure

// Returns an idea title.
//
// Parameters:
//  IdeaPresentation - XDTODataObject - idea.
//
// Returns:
//  String - idea title.
//
Function GenerateIdeaPreheader(Val IdeaPresentation) Export 
	
	Return IdeaPresentation.UserName + " (" + Format(IdeaPresentation.CreateDate, "DLF=DD") + ")";
	
EndFunction

// Creates comments title.
//
// Parameters:
//  IdeaPresentation - XDTODataObject - idea.
//
// Returns:
//  String - comments title.
//
Function GenerateCommentsTitle(Val IdeaPresentation) Export 
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Comments: %1';ru='Комментарии: %1'"), IdeaPresentation.CommentsCount);
	
EndFunction

// Creates implementation date title.
//
// Parameters:
//  IdeaPresentation - XDTODataObject - idea.
//
// Returns:
//  String - implementation date title.
//
Function GenerateImplementationDateTitle(Val IdeaPresentation) Export 
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Planned date of implementation:% 1';ru='Плановая дата реализации: %1'"), IdeaPresentation.PlanMadeDatePresentation);
	
EndFunction

// Creates rejection date title.
//
// Parameters:
//  IdeaPresentation - XDTODataObject - idea.
//
// Returns:
//  String - rejection date title.
//
Function GenerateRejectionDate(Val IdeaPresentation) Export 
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Rejected: %1';ru='Отклонено: %1'"), Format(IdeaPresentation.ClosingDate, "DLF=DD"));
	
EndFunction

// Creates implementation date title.
//
// Parameters:
//  IdeaPresentation - XDTODataObject - idea.
//
// Returns:
//  String - implementation date title.
//
Function GenerateImplementationDate(Val IdeaPresentation) Export 
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Implemented: %1';ru='Реализовано: %1'"), Format(IdeaPresentation.ClosingDate, "DLF=DD"));
	
EndFunction

// Generates a comment subtitle.
//
// Parameters:
//  CommentPresentation - XDTODataObject - comment.
//
// Returns:
//  String - comment subtitle.
//
Function GenerateCommentPreheader(Val CommentPresentation) Export 
	
	Return CommentPresentation.UserName + " (" + Format(CommentPresentation.Date, "DLF=DD") + " " + Format(CommentPresentation.Date, "DF=HH:mm") + ")";
	
EndFunction

// Creates a title of votes number.
//
// Parameters:
//  VotesNumber- Number - number of votes.
// PLUS - Boolean - plus flag.
//
// Returns:
//  String - number of votes.
//
Function GenerateVotesCount(Val VotesNumber, Val PLUS = True) Export 
	
	
	Return ?(PLUS, "+", "-") + " ("+ VotesNumber + ")";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Support requests

// Gets WSproxy of support service
//
// Return value:
//  WSProxy - WSproxy of support service
//
Function GetProxyServicesSupport() Export
	
	SetPrivilegedMode(True);
	ServiceAddress       = Constants.SupportServiceSoftwareInterfaceAddress.Get();
	UserName    = Constants.SupportServiceSoftwareInterfaceUserName.Get();
	UserPassword = Constants.SupportServiceSoftwareInterfaceUserPassword.Get();
	SetPrivilegedMode(False);
	
	SupportServiceProxy = ServiceTechnologyIntegrationWithSSL.WSProxy(ServiceAddress,
															"http://www.1c.ru/1cFresh/InformationCenter/SupportServiceData/1.0.0.1",
															"InformationCenterIntegration_1_0_0_1", 
															, 
															UserName, 
															UserPassword, 
															20);
	
	Return SupportServiceProxy;
	
EndFunction

// Exception text if support service is unavailable.
//
// Returns:
// String - exception text.
//
Function ErrorInformationTextOutputInSupport() Export 
	
	Return NStr("en='Support is temporarily unavailable.
		|Please try again later.';ru='Служба поддержки временно не доступна.
		|Пожалуйста, повторите попытку позже.'")
	
EndFunction

// Returns an image by a support request state.
//
// Parameters:
//  State - String - support request state.
//
// Returns:
//  Picture - picture.
//
Function PictureBySupportRequestState(State) Export 
	
	If State = "Closed" Then 
		Return PictureLib.ClosedTreatment;
	ElsIf State = "InProgress" Then
		Return PictureLib.AppealInProcess;
	ElsIf State = "New" Then
		Return PictureLib.NewAppeal;
	ElsIf State = "NeedAnswer" Then
		Return PictureLib.AppealAnswerIsNecessary;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Picture No by interaction type.
//
// Parameters:
//  TypeInteractions - String - interaction type.
//  Incoming - Boolean - whether interaction is incoming for the user.
//
// Returns:
//  Number - picture number.
//
Function PictureNumberByInteraction(TypeInteractions, Incoming) Export 
	
	If TypeInteractions = "Email" Then 
		If Incoming Then 
			Return 3;
		Else
			Return 4;
		EndIf;
	ElsIf TypeInteractions = "Comment" Then 
		Return 24;
	ElsIf TypeInteractions = "PhoneCall" Then 
		Return 2;
	EndIf;
	
	Return 0;
	
EndFunction

// Returns an email address of the current user.
//
// Returns:
//  String - email address of the current user.
//
Function DefineUserEmailAddress() Export 
	
	CurrentUser = Users.CurrentUser();
	
	If ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.ContactInformation") Then 
		
		Module = ServiceTechnologyIntegrationWithSSL.CommonModule("ContactInformationManagement");
		If Module = Undefined Then 
			Return "";
		EndIf;
		
		Return Module.ObjectContactInformation(CurrentUser, PredefinedValue("Catalog.ContactInformationTypes.UserEmail"));
		
	EndIf;
	
	Return "";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Support request (remote)

// Returns a support request template.
//
// Returns:
//  String - support request template.
//
Function GenerateTextTemplateToTechnicalSupport() Export
	
	Pattern = NStr("en='Hello!
		|<p/>
		|<p/>CursorPosition
		|<p/>
		|From respect, %1.';ru='Hello!
		|<p/>
		|<p/>CursorPosition
		|<p/>
		|From respect, %1.'");
	Pattern = StringFunctionsClientServer.SubstituteParametersInString(Pattern, 
			Users.CurrentUser().FullDescr());
	
	Return Pattern;
	
EndFunction

// Returns a attachment file name that contains
// technical parameters for support.
//
// Returns:
//  String - attachment file name.
//
Function GetTechnicalParametersFileNameForInformToSupport() Export
	
	Return "TechnicalParameters.xml";
	
EndFunction

// Returns a text of technical parameters.
//
// Returns:
//  Map:
// 	Key - String - file attachments.
// 	Value - BinaryData - attachment file.
//
Function GenerateXMLWithTechnicalParameters(AdditionalParameters = Undefined) Export
	
	ParameterArray = DefineTechnicalParametersArray(AdditionalParameters);
	
	XMLFile = GetTempFileName("xml");
	
	TextXML = New XMLWriter;
	TextXML.OpenFile(XMLFile);
	TextXML.WriteXMLDeclaration();
	WriteParametersInXML(TextXML, ParameterArray);
	TextXML.Close();
	
	FileBinaryData = New BinaryData(XMLFile);
	
	Try
		DeleteFiles(XMLFile);
	Except
		WriteLogEvent(NStr("en='Information center. Sending a message to support. Failed to delete the technical parameters temporary file.';ru='Информационный центр. Отправка сообщения в техподдержку. Не удалось удалить временный файл технических параметров.'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Attachment = New ValueList;
	Attachment.Add(FileBinaryData, GetTechnicalParametersFileNameForInformToSupport(), True);
	
	Return Attachment;
	
EndFunction

// Sends a message to support.
//
// Parameters:
//  MessageParameters - Structure - message parameters.
//  Result - Boolean - True if a message is sent, False - Else.
//
Procedure OnMessageSendingUserTechnicalSupport(MessageParameters, Result) Export
	
	If Not ServiceTechnologyIntegrationWithSSL.SubsystemExists("StandardSubsystems.SaaS") Then
		
		Result = True;
		Return;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		ServiceTechnologyIntegrationWithSSL.SendMessage("InformationCenter\MessageSending\TechSupport",
						MessageParameters,
						ServiceTechnologyIntegrationWithSSL.ServiceManagerEndPoint());
		CommitTransaction();
		Result = True;
		Return;
	Except
		RollbackTransaction();
		Result = False;
		Return;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// User notifications in Information center form

// Returns a reference to the catalog item "InformationCenterInformationTypes" by Name
//
// Parameters:
// Description - String - news type name.
//
// Returns:
// CatalogRef.InfoCenterInformationTypes - information type.
//
Function GetInformationTypeRef(Val Description) Export
	
	SetPrivilegedMode(True);
	Description = TrimAll(Description);
	
	FoundReference = Catalogs.InfoCentreInformationTypes.FindByDescription(Description);
	
	If FoundReference.IsEmpty() Then 
		InformationType = Catalogs.InfoCentreInformationTypes.CreateItem();
		InformationType.Description = Description;
		InformationType.Write();
		
		Return InformationType.Ref;
	Else
		Return FoundReference;
	EndIf;
	
EndFunction

// Determines a list of all news.
//
// Returns:
// ValuesTable with fields:
// 	Description - String - news header.
// 	ID - UUID - news identifier.
// 	Criticality - Number - news importance.
// 	ExternalRef - String - external reference address.
//
Function GenerateAllNewsList() Export
	
	AllNewsQuery = New Query;
	AllNewsQuery.SetParameter("CurrentDate", CurrentDate());
	AllNewsQuery.SetParameter("BlankDate", '00010101');
	AllNewsQuery.Text = 
	"SELECT
	|	InformationCenterCommonData.Ref AS Ref,
	|	InformationCenterCommonData.Ref.ActualityBeginningDate AS ActualityBeginningDate
	|INTO NewsList
	|FROM
	|	Catalog.InformationCenterCommonData AS InformationCenterCommonData
	|WHERE
	|	Not InformationCenterCommonData.DeletionMark
	|	AND InformationCenterCommonData.ActualityBeginningDate <= &CurrentDate
	|	AND InformationCenterCommonData.ActualityEndingDate >= &CurrentDate
	|
	|UNION
	|
	|SELECT
	|	InformationCenterCommonData.Ref,
	|	InformationCenterCommonData.Ref.ActualityBeginningDate
	|FROM
	|	Catalog.InformationCenterCommonData AS InformationCenterCommonData
	|WHERE
	|	Not InformationCenterCommonData.DeletionMark
	|	AND InformationCenterCommonData.ActualityBeginningDate <= &CurrentDate
	|	AND InformationCenterCommonData.ActualityEndingDate = &BlankDate
	|
	|INDEX BY
	|	Ref,
	|	ActualityBeginningDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 10
	|	NewsList.Ref.Criticality AS Criticality,
	|	NewsList.Ref.ID AS ID,
	|	NewsList.Ref.ExternalRef AS ExternalRef,
	|	NewsList.Ref.InformationType AS InformationType,
	|	NewsList.ActualityBeginningDate AS ActualityBeginningDate,
	|	NewsList.Ref.Description AS Description
	|FROM
	|	NewsList AS NewsList
	|
	|ORDER BY
	|	ActualityBeginningDate DESC";
	
	Return AllNewsQuery.Execute().Unload();
	
EndFunction

// Generates a list of news.
//
// Parameters:
// NewsTable - ValuesTable with columns:
// 	Description - String - news header.
// 	ID - UUID - news identifier.
// 	Criticality - Number - news importance.
// 	ExternalRef - String - external reference address.
// ShowedNewsNumber - Number - Number of news shown in the desktop.
//
Procedure GenerateNewsListToDesktop(NewsTable, Val ShowedNewsNumber = 3) Export
	
	CriticalNews = GenerateRelevanceCriticalNews();
	
	CriticalNewsQuantity = ?(CriticalNews.Count() >= ShowedNewsNumber, ShowedNewsNumber, CriticalNews.Count());
	
	// Adding news to a general table.
	If CriticalNewsQuantity > 0 Then 
		For Iteration = 0 to CriticalNewsQuantity - 1 Do
			News = NewsTable.Add();
			FillPropertyValues(News, CriticalNews.Get(Iteration));
		EndDo;	
	EndIf;
	
	If CriticalNewsQuantity = ShowedNewsNumber Then 
		Return;
	EndIf;
	
	NoncriticalNews = GenerateRelevanceNoncriticalNews();
	
	ShowedNoncriticalNewsNumber = ShowedNewsNumber - CriticalNewsQuantity;
	
	ShowedNoncriticalNewsNumber = ?(NoncriticalNews.Count() < ShowedNoncriticalNewsNumber, NoncriticalNews.Count(), ShowedNoncriticalNewsNumber);
	
	If NoncriticalNews.Count() > 0 Then 
		For Iteration = 0 to ShowedNoncriticalNewsNumber - 1 Do
			News = NewsTable.Add();
			FillPropertyValues(News, NoncriticalNews.Get(Iteration));
		EndDo;
	EndIf;
	
	Return;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Send messages to support service.

// Returns a size in megabytes, attachment size is not larger than 20 megabytes.
//
// Returns:
// Number - attachment size in megabytes.
//
Function AttachmentsMaximumSizeForSendingMessageToServiceSupport() Export
	
	Return 20;
	
EndFunction

// Returns a support request template.
//
// Returns:
// String - support request template.
//
Function TexttemplateToSupport() Export
	
	Pattern = NStr("en='Hello!
		|<p/>
		|<p/>CursorPosition
		|<p/>
		|From respect, %1.';ru='Hello!
		|<p/>
		|<p/>CursorPosition
		|<p/>
		|From respect, %1.'");
	Pattern = StringFunctionsClientServer.SubstituteParametersInString(Pattern, 
			Users.CurrentUser().FullDescr());
	
	Return Pattern;
	
EndFunction

// Returns a string with an external reference.
//
// Parameters:
// ID - UUID - unique identifier of news.
//
// Returns:
// String - external resource address.
//
Function GetExternalRefByNewsID(ID) Export
	
	SetPrivilegedMode(True);
	RefToData	= Catalogs.InformationCenterCommonData.FindByAttribute("ID", ID);
	If RefToData.IsEmpty() Then 
		Return "";
	EndIf;
	
	Return RefToData.ExternalRef;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// User notifications in Information center form

// Returns a list of actual critical news (severity > 5).
//
// Returns:
// ValuesTable with fields ValuesTables "NewsTable" in procedure GenerateNewsListToDesktop.
//
Function GenerateRelevanceCriticalNews()
	
	CriticalNewsQuery = New Query;
	
	CriticalNewsQuery.SetParameter("CurrentDate",                CurrentSessionDate());
	CriticalNewsQuery.SetParameter("CriticalityFive",            5);
	CriticalNewsQuery.SetParameter("BlankDate",                '00010101');
	
	CriticalNewsQuery.Text = 
	"SELECT
	|	InformationCenterCommonData.Ref AS RefToData
	|FROM
	|	Catalog.InformationCenterCommonData AS InformationCenterCommonData
	|WHERE
	|	InformationCenterCommonData.ActualityBeginningDate <= &CurrentDate
	|	AND InformationCenterCommonData.Criticality > &CriticalityFive
	|	AND (InformationCenterCommonData.ActualityEndingDate >= &CurrentDate
	|			OR InformationCenterCommonData.ActualityEndingDate = &BlankDate)
	|	AND Not InformationCenterCommonData.DeletionMark
	|
	|ORDER BY
	|	InformationCenterCommonData.Criticality DESC,
	|	InformationCenterCommonData.ActualityBeginningDate DESC";
	
	Return CriticalNewsQuery.Execute().Unload();
	
EndFunction

// Returns a list of actual non-critical news (criticality <= 5).
//
// Returns:
// ValuesTable with fields ValuesTables "NewsTable" in procedure GenerateNewsListToDesktop.
//
Function GenerateRelevanceNoncriticalNews()
	
	SetPrivilegedMode(True);
	
	NonCriticalNewsQuery = New Query;
	
	NonCriticalNewsQuery.SetParameter("CurrentDate",     CurrentDate()); // Project decision SSL
	NonCriticalNewsQuery.SetParameter("CriticalityFive", 5);
	NonCriticalNewsQuery.SetParameter("BlankDate",      '00010101');
	NonCriticalNewsQuery.SetParameter("Viewed",     False);
	NonCriticalNewsQuery.SetParameter("User",    Users.CurrentUser().Ref);
	
	NonCriticalNewsQuery.Text =
	"SELECT
	|	InformationCenterCommonData.Ref AS RefToData
	|INTO ICData
	|FROM
	|	Catalog.InformationCenterCommonData AS InformationCenterCommonData
	|WHERE
	|	InformationCenterCommonData.ActualityBeginningDate <= &CurrentDate
	|	AND InformationCenterCommonData.Criticality <= &CriticalityFive
	|	AND (InformationCenterCommonData.ActualityEndingDate >= &CurrentDate
	|			OR InformationCenterCommonData.ActualityEndingDate = &BlankDate)
	|	AND Not InformationCenterCommonData.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InformationCenterViewedData.DataInformationCenter,
	|	InformationCenterViewedData.Viewed
	|INTO UserHasRecentlyViewed
	|FROM
	|	InformationRegister.InformationCenterViewedData AS InformationCenterViewedData
	|WHERE
	|	InformationCenterViewedData.User = &User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ICData.RefToData,
	|	ISNULL(UserHasRecentlyViewed.Viewed, &Viewed) AS Viewed
	|INTO Finished
	|FROM
	|	ICData AS ICData
	|		Full JOIN UserHasRecentlyViewed AS UserHasRecentlyViewed
	|		ON ICData.RefToData = UserHasRecentlyViewed.DataInformationCenter
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Finished.RefToData
	|FROM
	|	Finished AS Finished
	|WHERE
	|	Finished.Viewed = &Viewed";
	
	Return NonCriticalNewsQuery.Execute().Unload();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Information references

// Creates info references of form items in a group.
//
// Parameters:
// Form - ManagedForm - form context.
// FormGroup - FormItem - group of a form in which info references are displayed.
// GroupCount - Number - number of info references groups in a form.
// RefsCountInGroup - Number - number of info references in a group.
// OutputReferenceAll - Boolean - show or not reference "All".
//
Procedure GenerateOutputGroups(Form, RefsTable, FormGroup, GroupCount, RefsCountInGroup, OutputReferenceAll)
	
	QuantityRefs = ?(RefsTable.Count() > GroupCount * RefsCountInGroup, GroupCount * RefsCountInGroup, RefsTable.Count());
	
	GroupCount = ?(QuantityRefs < GroupCount, QuantityRefs, GroupCount);
	
	IncompleteGroupName = "GroupInformationLinks";
	
	For Iteration = 1 To GroupCount Do 
		
		FormItemName                            = IncompleteGroupName + String(Iteration);
		ParentGroup                          = Form.Items.Add(FormItemName, Type("FormGroup"), FormGroup);
		ParentGroup.Type                      = FormGroupType.UsualGroup;
		ParentGroup.ShowTitle      = False;
		ParentGroup.Group              = ChildFormItemsGroup.Vertical;
		ParentGroup.Representation              = UsualGroupRepresentation.None;
		
	EndDo;
	
	For Iteration = 1 To QuantityRefs Do 
		
		GroupLinks = GetReferenceGroup(Form, GroupCount, IncompleteGroupName, Iteration);
		
		ReferenceName      = RefsTable.Get(Iteration - 1).Description;
		Address          = RefsTable.Get(Iteration - 1).Address;
		ToolTip      = RefsTable.Get(Iteration - 1).ToolTip;
		
		ReferenceItem                          = Form.Items.Add("ReferenceItem" + String(Iteration), Type("FormDecoration"), GroupLinks);
		ReferenceItem.Type                      = FormDecorationType.Label;
		ReferenceItem.Title                = ReferenceName;
		ReferenceItem.HorizontalStretch = True;
		ReferenceItem.Height                   = 1;
		ReferenceItem.Hyperlink              = True;
		ReferenceItem.SetAction("Click", "Attachable_ClickOnInformationLink");
		
		Form.InformationReferences.Add(ReferenceItem.Name, Address);
		
	EndDo;
	
	If OutputReferenceAll Then 
		Item                         = Form.Items.Add("RefsAllInformationReferences", Type("FormDecoration"), FormGroup);
		Item.Type                     = FormDecorationType.Label;
		Item.Title               = NStr("en='All';ru='Все'");
		Item.Hyperlink             = True;
		Item.TextColor              = WebColors.Black;
		Item.HorizontalAlign = ItemHorizontalLocation.Right;
		Item.SetAction("Click", "Attachable_ClickOnLinkAllInformationLinks")
	EndIf;
	
EndProcedure

// Returns a group in which it is required to display info refs.
//
// Parameters:
// Form - ManagedForm - form context.
// GroupCount - Number - number of groups with info references in a form.
// IncompleteGroupName - String - not full group name.
// CurrentIteration - Number - current iteration.
//
// Returns:
// FormItem - information references group or undefined.
//
Function GetReferenceGroup(Form, GroupCount, IncompleteGroupName, CurrentIteration)
	
	GroupName = "";
	
	For GroupsIteration = 1 To GroupCount Do
		
		If CurrentIteration % GroupsIteration  = 0 Then 
			GroupName = IncompleteGroupName + String(GroupsIteration);
		EndIf;
		
	EndDo;
	
	Return Form.Items.Find(GroupName);
	
EndFunction

// Returns a hash of a full form path by an algorithm.
//
// Parameters:
// FullPathToForm - String - full path to a form.
//
// Returns:
// String - hash.
//
Function FullPathToFormHash(Val FullPathToForm)
	
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(FullPathToForm);
	Return StrReplace(DataHashing.HashSum, " ", "");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Send messages to the service support (deleted)

// Returns an array of technical parameters.
//
// Returns:
// Array  - array of technical parameter structure with fields:
// 	Name - String - parameter name.
// 	Value - String - value of the parameter.
//
Function DefineTechnicalParametersArray(AdditionalParameters)
	
	System_Info = New SystemInfo;
	
	ParameterArray = New Array;
	ParameterArray.Add(New Structure("Name, Value", "ConfigurationName",    Metadata.Name));
	ParameterArray.Add(New Structure("Name, Value", "ConfigurationVersion", Metadata.Version));
	ParameterArray.Add(New Structure("Name, Value", "PlatformVersion",    System_Info.AppVersion));
	ParameterArray.Add(New Structure("Name, Value", "DataArea",      String(Format(ServiceTechnologyIntegrationWithSSL.SessionSeparatorValue(), "NG=0"))));
	ParameterArray.Add(New Structure("Name, Value", "Login",              UserName()));
	
	If AdditionalParameters <> Undefined Then 
		For Each Parameter IN AdditionalParameters Do
			ParameterArray.Add(New Structure("Name, Value", Parameter.Key, String(Parameter.Value)));
		EndDo;
	EndIf;
	
	Return ParameterArray;
	
EndFunction	

// Writes parameters to XML.
//
// Parameters:
// TextXML - XMLWriter - writing XML.
// ParameterArray - parameter array.
//
Procedure WriteParametersInXML(TextXML, ParameterArray)
	
	TextXML.WriteStartElement("parameters");
	For Iteration = 0 to ParameterArray.Count() - 1 Do 
		TextXML.WriteStartElement("parameter");
		Item = ParameterArray.Get(Iteration);
		TextXML.WriteAttribute(Item.Name, Item.Value);
		TextXML.WriteEndElement();
	EndDo;
	TextXML.WriteEndElement();
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for deletion.

// Describes the website reference to publish applications on the Internet.
// 
// Returns:
// Structure - structure with fields that describe the website reference. 
//	
Function WebsiteForPublishingApplicationsViaInternetLinkNewDescription() Export 
	
	Return New Structure("Name, Address");
	
EndFunction

// Describes structure of the useful reference.
//	
// Returns:
// Structure - structure with fields that describe a useful ref:
// 	Name - String - useful reference name.
// 	Address - String - useful reference address.
// 	Explanation - String - useful reference explanation.
// 	ActionByClick - String - useful reference procedure-handler.
//	
// Note:
// It is not required to select "ActionByClick" if hyperlink navigation is supposed.
//
Function UsefulReferenceNewDescription() Export
	
	Return New Structure("Name, Address, Explanation, ActionByClick");
	
EndFunction

// Describes an item structure.
// 
// Returns:
// Structure - structure with fields that describe an item. 
//	
Function ItemNewDescription() Export
	
	Return New Structure("Name, Address");
	
EndFunction	



	



