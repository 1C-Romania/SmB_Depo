
//////////////////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

&AtServer
Procedure UpdateQueryText()

	TempQueryText = "";
	For Each TabRow IN RequestsTable.FindRows(New Structure("Use", True)) Do

		TempQueryText = TempQueryText + ?(IsBlankString(TempQueryText), "", " UNION ALL ")
				+ TabRow.QueryText;

	EndDo;

	Position = Find(UPPER(TempQueryText), Upper("Select"));
	If Position > 0 Then

		TempQueryText = "SELECT ALLOWED " + Mid(TempQueryText, Position + StrLen("Select")) + 
		"ORDER
		|	BY
		|	Date, Document
		|";

	EndIf;

	QueryTextByDocuments = TempQueryText;

EndProcedure

&AtServer
Procedure SetFlagOfDocumentKindUsage()

	For Each TabRow IN RequestsTable Do

		ItemOfList = DocumentsKindsList.FindByValue(TabRow.DocumentName);
		If ItemOfList <> Undefined Then
			TabRow.Use = ItemOfList.Check;
		EndIf;

	EndDo;

EndProcedure

&AtServer
Procedure UpdateDocumentKindsList()

	DocumentsKindsList.Clear();
	For Each String IN RequestsTable Do
		DocumentsKindsList.Add(String.DocumentName, String.DocumentSynonym, String.Use);
	EndDo;

	DocumentsKindsList.SortByPresentation(SortDirection.Asc);

EndProcedure

&AtServer
Procedure ApplySettingsToDocumentKindsList(SettingValue)

	RearrangeQuery = False;
	For Each Item IN SettingValue Do

		ItemOfList = DocumentsKindsList.FindByValue(Item.Value);
		If ItemOfList <> Undefined AND ItemOfList.Check <> Item.Check Then

			ItemOfList.Check = Item.Check;
			RearrangeQuery = True;

		EndIf;

	EndDo;

	If RearrangeQuery Then

		SetFlagOfDocumentKindUsage();

		UpdateQueryText();

		SaveSettings();

	EndIf;

EndProcedure

&AtClient
Procedure EditContentOfDocuments()

	Notification = New NotifyDescription("EditContentOfDocumentsEnd",ThisForm);
	OpenForm(FormNameDocumentKindsContentSetting,
				New Structure("DocumentsKindsList", DocumentsKindsList),,,,,Notification);

EndProcedure

&AtClient
Procedure EditContentOfDocumentsEnd(Result,Parameters) Export
	
	If TypeOf(Result) = Type("ValueList") Then
		ApplySettingsToDocumentKindsList(Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateDocumentsTableAtServer()
	
	If IsBlankString(QueryTextByDocuments) Then
		
		CommonUseClientServer.MessageToUser(NStr("en='It is neccesary to set content of documents';ru='Необходимо настроить состав документов'"),,"ThisForm");
		Return;
		
	EndIf;
	
	Query = New Query(QueryTextByDocuments);
	Query.SetParameter("Parameter", Parameter);
	
	ValueToFormAttribute(Query.Execute().Unload(), "DocumentsTable");
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////
// Work procedure with settings.

&AtServer
Procedure RestoreSettings()
	
	SettingsValue = CommonSettingsStorage.Load("DataProcessor.DocumentsByCounterparty", SettingsKey);
	If TypeOf(SettingsValue) = Type("Map") Then
		
		ValueFromSetting = SettingsValue.Get("DocumentsKindsList");
		If TypeOf(ValueFromSetting) = Type("ValueList") Then
			ApplySettingsToDocumentKindsList(ValueFromSetting);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	Settings = New Map;
	Settings.Insert("DocumentsKindsList", DocumentsKindsList);
	
	CommonSettingsStorage.Save("DataProcessor.DocumentsByCounterparty", SettingsKey, Settings);
	
EndProcedure

&AtServer
Procedure ApplyCommandParameters()

	If Parameters.Property("Filter") Then

		Parameters.Filter.Property("Counterparty", Parameter);

	EndIf;

	If Parameters.Property("GenerateOnOpen") AND Parameters.GenerateOnOpen Then

		UpdateDocumentsTableAtServer();

	EndIf;

EndProcedure

&AtServer
Procedure FillQueryTable(DataProcessorObject)

	AdditionalDocuments = New Array;
	AdditionalDocuments.Add(Metadata.Documents.GoodsExpense);
	AdditionalDocuments.Add(Metadata.Documents.GoodsReceipt);

	HeaderFields = New Array;
	HeaderFields.Add("DocumentAmount");
	HeaderFields.Add("OperationKind");
	HeaderFields.Add("DocumentCurrency");
	HeaderFields.Add("Division");
	HeaderFields.Add("Company");
	HeaderFields.Add("Responsible");
	HeaderFields.Add("Comment");
	HeaderFields.Add("Author");

	DataProcessorObject.FillQueryTable(RequestsTable,
			AdditionalDocuments,
			HeaderFields);

EndProcedure

&AtServer
Procedure SetSettingsKey()

	If Parameters.Property("SettingsKey") AND Not IsBlankString(Parameters.SettingsKey) Then

		SettingsKey = Parameters.SettingsKey;

	Else

		SettingsKey = "WithoutCounterparty";

	EndIf;

	SettingsKey = SettingsKey + "_" + Users.CurrentUser().UUID();

	If Parameters.Property("Filter") AND Parameters.Filter.Property("Counterparty") Then

		SettingsKey = SettingsKey + "_" + Parameters.Filter.Counterparty.UUID();

	EndIf;

EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	DataProcessorObject = FormAttributeToValue("Object");

	FormNameDocumentKindsContentSetting = DataProcessorObject.Metadata().FullName()
			+ ".Form.DocumentsKindsCompositionSetting";

	SetSettingsKey();

	FillQueryTable(DataProcessorObject);

	UpdateDocumentKindsList();

	RestoreSettings();

	UpdateQueryText();

	ApplyCommandParameters();

EndProcedure

&AtClient
Procedure OnClose()

	SaveSettings();

EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure SetContentOfDocuments(Command)

	EditContentOfDocuments();

EndProcedure

&AtClient
Procedure Generate(Command)

	UpdateDocumentsTableAtServer();

EndProcedure

&AtClient
Procedure Edit(Command)

	CurrentData = Items.DocumentsTable.CurrentData;
	If CurrentData <> Undefined Then

		ShowValue(Undefined,CurrentData.Document);

	EndIf;

EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////
// Event handlers DocumentsTable

&AtClient
Procedure DocumentsTableSelection(Item, SelectedRow, Field, StandardProcessing)

	ShowValue(Undefined,Item.CurrentData.Document);

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
