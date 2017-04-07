#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// OBJECT EVENT HANDLERS

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ResultDocument.Clear();
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Settings = SettingsComposer.GetSettings();
	
	NonExistentInfobaseUserIDs = New Array;
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("IBUsers", IBUsers(NonExistentInfobaseUserIDs));
	ExternalDataSets.Insert("ContactInformation", ContactInformation(Settings));
	
	Settings.DataParameters.SetParameterValue(
		"NonExistentInfobaseUserIDs", NonExistentInfobaseUserIDs);
	
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.BeginOutput();
	ResultItem = CompositionProcessor.Next();
	While ResultItem <> Undefined Do
		OutputProcessor.OutputItem(ResultItem);
		ResultItem = CompositionProcessor.Next();
	EndDo;
	OutputProcessor.EndOutput();
	
EndProcedure

#Region ServiceProceduresAndFunctions

Function IBUsers(NonExistentInfobaseUserIDs)
	
	EmptyUUID = New UUID("00000000-0000-0000-0000-000000000000");
	NonExistentInfobaseUserIDs.Add(EmptyUUID);
	
	Query = New Query;
	Query.SetParameter("EmptyUUID", EmptyUUID);
	Query.Text =
	"SELECT
	|	Users.InfobaseUserID,
	|	Users.InfobaseUserProperties
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID <> &EmptyUUID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.InfobaseUserID,
	|	ExternalUsers.InfobaseUserProperties
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.InfobaseUserID <> &EmptyUUID";
	
	Exporting = Query.Execute().Unload();
	Exporting.Indexes.Add("InfobaseUserID");
	Exporting.Columns.Add("Mapped", New TypeDescription("Boolean"));
	
	IBUsers = InfobaseUsers.GetUsers();
	IBUsers = New ValueTable;
	IBUsers.Columns.Add("UUID", New TypeDescription("UUID"));
	IBUsers.Columns.Add("Name", New TypeDescription("String",,,, New StringQualifiers(100)));
	IBUsers.Columns.Add("CanLogOnToApplication",    New TypeDescription("Boolean"));
	IBUsers.Columns.Add("StandardAuthentication", New TypeDescription("Boolean"));
	IBUsers.Columns.Add("ShowInList",   New TypeDescription("Boolean"));
	IBUsers.Columns.Add("CannotChangePassword",   New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OpenIDAuthentication",      New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OSAuthentication",          New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OSUser", New TypeDescription("String",,,, New StringQualifiers(1024)));
	IBUsers.Columns.Add("Language",           New TypeDescription("String",,,, New StringQualifiers(100)));
	IBUsers.Columns.Add("RunMode",   New TypeDescription("String",,,, New StringQualifiers(100)));
	
	AllIBUsers = InfobaseUsers.GetUsers();
	
	For Each IBUser IN AllIBUsers Do
		PropertiesIBUser = Users.NewInfobaseUserInfo();
		Users.ReadIBUser(IBUser.UUID, PropertiesIBUser);
		NewRow = IBUsers.Add();
		FillPropertyValues(NewRow, PropertiesIBUser);
		Language = PropertiesIBUser.Language;
		NewRow.Language = ?(ValueIsFilled(Language), Metadata.Languages[Language].Synonym, "");
		NewRow.CanLogOnToApplication = Users.CanLogOnToApplication(PropertiesIBUser);
		
		String = Exporting.Find(PropertiesIBUser.UUID, "InfobaseUserID");
		If String <> Undefined Then
			String.Mapped = True;
			If Not NewRow.CanLogOnToApplication Then
				FillPropertyValues(NewRow,
					UsersService.StoredInfobaseUserProperties(String));
			EndIf;
		EndIf;
	EndDo;
	
	Filter = New Structure("Mapped", False);
	Rows = Exporting.FindRows(Filter);
	For Each String IN Rows Do
		NonExistentInfobaseUserIDs.Add(String.InfobaseUserID);
	EndDo;
	
	Return IBUsers;
	
EndFunction

Function ContactInformation(Settings)
	
	RefTypes = New Array;
	RefTypes.Add(Type("CatalogRef.Users"));
	RefTypes.Add(Type("CatalogRef.ExternalUsers"));
	
	Contacts = New ValueTable;
	Contacts.Columns.Add("Ref", New TypeDescription(RefTypes));
	Contacts.Columns.Add("Phone", New TypeDescription("String"));
	Contacts.Columns.Add("EmailAddress", New TypeDescription("String"));
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return Contacts;
	EndIf;
	
	FillContacts = False;
	FieldPhone          = New DataCompositionField("Phone");
	FieldEmailAddress = New DataCompositionField("EmailAddress");
	
	For Each Item IN Settings.Selection.Items Do
		If TypeOf(Item) = Type("DataCompositionSelectedField")
		   AND (Item.Field = FieldPhone Or Item.Field = FieldEmailAddress)
		   AND Item.Use Then
			
			FillContacts = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FillContacts Then
		Return Contacts;
	EndIf;
	
	ContactInformationKinds = New Array;
	ContactInformationKinds.Add(Catalogs["ContactInformationKinds"].UserEmail);
	ContactInformationKinds.Add(Catalogs["ContactInformationKinds"].UserPhone);
	Query = New Query;
	Query.SetParameter("ContactInformationKinds", ContactInformationKinds);
	Query.Text =
	"SELECT
	|	UsersContactInformation.Ref AS Ref,
	|	UsersContactInformation.Type,
	|	UsersContactInformation.Presentation
	|FROM
	|	Catalog.Users.ContactInformation AS UsersContactInformation
	|WHERE
	|	UsersContactInformation.Type IN (&ContactInformationKinds)
	|
	|ORDER BY
	|	UsersContactInformation.Ref,
	|	UsersContactInformation.Type.Order,
	|	UsersContactInformation.Type";
	
	Selection = Query.Execute().Select();
	
	CurrentRef = Undefined;
	PhoneNumbers = "";
	EmailAddresses = "";
	
	While Selection.Next() Do
		If CurrentRef <> Selection.Ref Then
			If CurrentRef <> Undefined Then
				If ValueIsFilled(PhoneNumbers) Or ValueIsFilled(EmailAddresses) Then
					NewRow = Contacts.Add();
					NewRow.Ref = CurrentRef;
					NewRow.Phone = PhoneNumbers;
					NewRow.EmailAddress = EmailAddresses;
				EndIf;
			EndIf;
			PhoneNumbers = "";
			EmailAddresses = "";
			CurrentRef = Selection.Ref;
		EndIf;
		If Selection.Type = Catalogs["ContactInformationKinds"].UserPhone Then
			PhoneNumbers = PhoneNumbers + ?(ValueIsFilled(PhoneNumbers), ", ", "");
			PhoneNumbers = PhoneNumbers + Selection.Presentation;
		EndIf;
		If Selection.Type = Catalogs["ContactInformationKinds"].UserEmail Then
			EmailAddresses = EmailAddresses + ?(ValueIsFilled(EmailAddresses), ", ", "");
			EmailAddresses = EmailAddresses + Selection.Presentation;
		EndIf;
	EndDo;
	
	Return Contacts;
	
EndFunction

#EndRegion

#EndIf
