

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Ref = Parameters.Ref;
	
	If ObjectVersioning.LastVersionNumber(Ref) = 0 Then
		Items.MainPage.CurrentPage = Items.VersionsForCompareThereAreNo;
		Items.NoneOfVersions.Title = StringFunctionsClientServer.SubstituteParametersInString(
	       NStr("en='Previous versions are missing: ""%1"".';ru='Предыдущие версии отсутствуют: ""%1"".'"),
	       String(Ref));
	EndIf;
	
	UpdateVersionList();
	
	TransitionToVersionAllowed = Users.InfobaseUserWithFullAccess();
	Items.GoToVersion.Visible = TransitionToVersionAllowed;
	Items.VersionsListGoToVersion.Visible = TransitionToVersionAllowed;
	Items.TechnicalInformationOnObjectChange.Visible = TransitionToVersionAllowed;
	
	Attributes = NStr("en='All';ru='Все'")
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEnabled();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure AttributesSelectionStart(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("OnAttributeSelection", ThisObject);
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectAttributesChoice", New Structure(
		"Ref,Filter", Ref, Filter.UnloadValues()), , , , , NotifyDescription);
EndProcedure

&AtClient
Procedure EventLogMonitorClick(Item)
	EventLogMonitorClient.OpenEventLogMonitor();
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersVersionList

&AtClient
Procedure VersionsListOnActivateRow(Item)
	
	SetEnabled();
	
EndProcedure

&AtClient
Procedure VersionsListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenReportByObjectVersioning();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenObjectVersioning(Command)
	
	OpenReportByObjectVersioning();
	
EndProcedure

&AtClient
Procedure GoToVersion(Command)
	
	GoToSelectedVersion();
	
EndProcedure

&AtClient
Procedure GenerateChangesReport(Command)
	
	SelectedRows = Items.VersionsList.SelectedRows;
	ComparedVersions = GenerateListOfSelectedVersions(SelectedRows);
	
	If ComparedVersions.Count() < 2 Then
		ShowMessageBox(, NStr("en='To generate a report on changes, select at least two versions.';ru='Для формирования отчета по изменениям необходимо выбрать хотя бы две версии.'"));
		Return;
	EndIf;
	
	OpenReportForm(ComparedVersions);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function GenerateVersionsTable()
	
	If ObjectVersioning.HasRightToReadVersions() Then
		SetPrivilegedMode(True);
	EndIf;
	
	VersionNumbers = New Array;
	If Filter.Count() > 0 Then
		VersionNumbers = VersionNumbersWithChangesInSelectedAttributes();
	EndIf;
	
	QueryText = 
	"SELECT
	|	ObjectVersionings.VersionNumber AS VersionNumber,
	|	ObjectVersionings.VersionAuthor AS VersionAuthor,
	|	ObjectVersionings.VersionDate AS VersionDate,
	|	ObjectVersionings.Comment AS Comment
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.Object = &Ref
	|	AND (&WithoutFilter
	|			OR ObjectVersionings.VersionNumber IN (&VersionNumbers))
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("WithoutFilter", Filter.Count() = 0);
	Query.SetParameter("VersionNumbers", VersionNumbers);
	Query.SetParameter("Ref", Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtClient
Procedure GoToSelectedVersion(CancelPosting = False)
	
	If Items.VersionsList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Result = GoToVersionServer(Ref, Items.VersionsList.CurrentData.VersionNumber, CancelPosting);
	
	If Result = "RecoveryError" Then
		CommonUseClientServer.MessageToUser(ErrorMessageText);
	ElsIf Result = "PostingError" Then
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Version was not changed due to: 
		|%1
		|Change to the selected version and cancel the posting?';ru='Переход на версию не был выполнен по причине:
		|%1
		|Перейти на выбранную версию с отменой проведения?'"),
			ErrorMessageText);
			
		NotifyDescription = New NotifyDescription("GoToSelectedVersionQueryIsAsked", ThisObject);
		Buttons = New ValueList;
		Buttons.Add("Goto", NStr("en='Navigate';ru='Перейти'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NOTifyDescription, QuestionText, Buttons);
	Else //Result = "RecoveryIsCompleted"
		NotifyChanged(Ref);
		If FormOwner <> Undefined Then
			Try
				FormOwner.Read();
			Except
				// Do nothing if the form has no Read() method.
			EndTry;
		EndIf;
		ShowMessageBox(, NStr("en='Migration to the previous version is completed successfully.';ru='Переход к старой версий выполнен успешно.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToSelectedVersionQueryIsAsked(QuestionResult, AdditionalParameters) Export
	If QuestionResult <> "Goto" Then
		Return;
	EndIf;
	
	GoToSelectedVersion(True);
EndProcedure

&AtServer
Function GoToVersionServer(Ref, VersionNumber, UndoPosting = False)
	
	Information = ObjectVersioning.InfoAboutObjectVersion(Ref, VersionNumber);
	AddressInTemporaryStorage = PutToTempStorage(Information.ObjectVersion);
	
	ErrorMessageText = "";
	Object = ObjectVersioning.RestoreObjectByXML(AddressInTemporaryStorage, ErrorMessageText);
	
	If Not IsBlankString(ErrorMessageText) Then
		Return "RecoveryError";
	EndIf;
	
	Object.AdditionalProperties.Insert("ObjectVersioningCommentToVersion",
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Transfer to version No. %1 from %2 is performed';ru='Выполнен переход к версии №%1 от %2'"),
			String(VersionNumber),
			Format(Information.VersionDate, "DLF=DT")) );
			
	WriteMode = DocumentWriteMode.Write;
	If CommonUse.ThisIsDocument(Object.Metadata()) Then
		If Object.Posted AND Not UndoPosting Then
			WriteMode = DocumentWriteMode.Posting;
		Else
			WriteMode = DocumentWriteMode.UndoPosting;
		EndIf;
		
		Try
			Object.Write(WriteMode);
		Except
			ErrorMessageText = BriefErrorDescription(ErrorInfo());
			Return "PostingError"
		EndTry;
	Else
		Try
			Object.Write();
		Except
			ErrorMessageText = BriefErrorDescription(ErrorInfo());
			Return "RecoveryError"
		EndTry;
	EndIf;
	
	
	UpdateVersionList();
	
	Return "RestorationIsCompleted";
	
EndFunction

&AtClient
Procedure OpenReportByObjectVersioning()
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Items.VersionsList.CurrentData.VersionNumber);
	OpenReportForm(ComparedVersions);
	
EndProcedure

&AtClient
Procedure OpenReportForm(ComparedVersions)
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("ComparedVersions", ComparedVersions);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ReportOnObjectVersions",
		ReportParameters,
		ThisObject,
		UUID);
	
EndProcedure

&AtClient
Function GenerateListOfSelectedVersions(SelectedRows)
	
	ComparedVersions = New ValueList;
	
	For Each SelectedRowsNumber IN SelectedRows Do
		ComparedVersions.Add(Items.VersionsList.RowData(SelectedRowsNumber).VersionNumber);
	EndDo;
	
	ComparedVersions.SortByValue(SortDirection.Asc);
	
	Return ComparedVersions.UnloadValues();
	
EndFunction

&AtClient
Procedure SetEnabled()
	
	OneVersionIsSelected = Items.VersionsList.SelectedRows.Count() = 1;
	SeveralVersionsAreSelected = Items.VersionsList.SelectedRows.Count() > 1;
	
	Items.OpenObjectVersioning.Enabled = OneVersionIsSelected;
	Items.VersionsListOpenObjectVersioning.Enabled = OneVersionIsSelected;
	
	Items.ReportByChanges.Enabled = SeveralVersionsAreSelected;
	Items.VersionsListReportOnChanges.Enabled = SeveralVersionsAreSelected;
	
	Items.GoToVersion.Enabled = OneVersionIsSelected;
	Items.VersionsListGoToVersion.Enabled = OneVersionIsSelected;
	
EndProcedure

&AtClient
Procedure OnAttributeSelection(ChoiceResult, AdditionalParameters) Export
	If ChoiceResult = Undefined Then
		Return;
	EndIf;
	
	Attributes = ChoiceResult.SelectedPresentation;
	Filter.LoadValues(ChoiceResult.SelectedAttributes);
	UpdateVersionList();
EndProcedure

&AtServer
Procedure UpdateVersionList()
	ValueToFormAttribute(GenerateVersionsTable(), "VersionsList");
EndProcedure

&AtClient
Procedure AttributesClearing(Item, StandardProcessing)
	StandardProcessing = False;
	Attributes = NStr("en='All';ru='Все'");
	Filter.Clear();
	UpdateVersionList();
EndProcedure

&AtServer
Function VersionNumbersWithChangesInSelectedAttributes()
	
	QueryText =
	"SELECT
	|	ObjectVersionings.VersionNumber AS VersionNumber,
	|	ObjectVersionings.ObjectVersion AS Data
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.ObjectVersioningType = VALUE(Enum.ObjectVersionsTypes.ChangedByUser)
	|	AND ObjectVersionings.Object = &Ref
	|	AND ObjectVersionings.ThereIsVersionData
	|
	|ORDER BY
	|	VersionNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	StoredVersions = Query.Execute().Unload();
	
	CurrentVersion = StoredVersions.Add();
	CurrentVersion.Data = New ValueStorage(ObjectVersioning.SerializeObject(Ref.GetObject()), New Deflation(9));
	CurrentVersion.VersionNumber = ObjectVersioning.LastVersionNumber(Ref);
	
	PreviousVersion = ObjectVersioning.ParsingObjectXMLPresentation(StoredVersions[0].Data.Get(), Ref);
	
	Result = New Array;
	Result.Add(StoredVersions[0].VersionNumber);
	
	For VersionNumber = 1 To StoredVersions.Count() - 1 Do
		Version = StoredVersions[VersionNumber];
		CurrentVersion = ObjectVersioning.ParsingObjectXMLPresentation(Version.Data.Get(), Ref);
		If ThereIsAttributeChange(CurrentVersion, PreviousVersion, Filter.UnloadValues()) Then
			Result.Add(Version.VersionNumber);
		EndIf;
		PreviousVersion = CurrentVersion;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function ThereIsAttributeChange(CurrentVersion, PreviousVersion, AttributesList)
	For Each Attribute IN AttributesList Do
		TabularSectionName = Undefined;
		AttributeName = Attribute;
		If Find(AttributeName, ".") > 0 Then
			NameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(AttributeName, ".", True);
			If NameParts.Count() > 1 Then
				TabularSectionName = NameParts[0];
				AttributeName = NameParts[1];
			EndIf;
		EndIf;
		
		// Checking attribute change of tabular section.
		If TabularSectionName <> Undefined Then
			CurrentTabularSection = CurrentVersion.TabularSections[TabularSectionName];
			PreviousTabularSection = PreviousVersion.TabularSections[TabularSectionName];
			
			// There is no tabular section.
			If CurrentTabularSection = Undefined Or PreviousTabularSection = Undefined Then
				Return Not CurrentTabularSection = Undefined AND PreviousTabularSection = Undefined;
			EndIf;
			
			// If the number of TS rows was changed.
			If CurrentTabularSection.Count() <> PreviousTabularSection.Count() Then
				Return True;
			EndIf;
			
			// attribute isn't available
			CurrentAttributeExist = CurrentTabularSection.Columns.Find(AttributeName) <> Undefined;
			PreviousAttributeExist = PreviousTabularSection.Columns.Find(AttributeName) <> Undefined;
			If CurrentAttributeExist <> PreviousAttributeExist Then
				Return True;
			EndIf;
			If Not CurrentAttributeExist Then
				Return False;
			EndIf;
			
			// comparison by rows
			For LineNumber = 0 To CurrentTabularSection.Count() - 1 Do
				If CurrentTabularSection[LineNumber][AttributeName] <> PreviousTabularSection[LineNumber][AttributeName] Then
					Return True;
				EndIf;
			EndDo;
			
			Return False;
		EndIf;
		
		// checking header attribute
		
		CurrentAttribute = CurrentVersion.Attributes.Find(AttributeName, "DescriptionAttribute");
		CurrentAttributeExist = CurrentAttribute <> Undefined;
		CurrentAttributeValue = Undefined;
		If CurrentAttributeExist Then
			CurrentAttributeValue = CurrentAttribute.AttributeValue;
		EndIf;
		
		PreviousAttribute = PreviousVersion.Attributes.Find(AttributeName, "DescriptionAttribute");
		PreviousAttributeExist = PreviousAttribute <> Undefined;
		PreviousAttributeValue = Undefined;
		If PreviousAttributeExist Then
			PreviousAttributeValue = PreviousAttribute.AttributeValue;
		EndIf;
		
		If CurrentAttributeExist <> PreviousAttributeExist
			Or CurrentAttributeValue <> PreviousAttributeValue Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

&AtClient
Procedure VersionsListCommentOnChange(Item)
	CurrentData = Items.VersionsList.CurrentData;
	If CurrentData <> Undefined Then
		AddCommentToVersions(Ref, CurrentData.VersionNumber, CurrentData.Comment);
	EndIf;
EndProcedure

&AtServerNoContext
Procedure AddCommentToVersions(ObjectReference, VersionNumber, Comment);
	ObjectVersioning.AddCommentToVersions(ObjectReference, VersionNumber, Comment);
EndProcedure

&AtClient
Procedure VersionsListBeforeStartChanging(Item, Cancel)
	If Not CommentEditIsAllowed(Item.CurrentData.VersionAuthor) Then
		Cancel = True;
	EndIf;
EndProcedure

&AtServer
Function CommentEditIsAllowed(VersionAuthor)
	Return Users.InfobaseUserWithFullAccess()
		Or VersionAuthor = Users.CurrentUser();
EndFunction

#EndRegion
