
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If TypeOf(Parameters.CounterpartiesInitialValue) = Type("Array") Then
		CounterpartiesList.LoadValues(Parameters.CounterpartiesInitialValue);
		CounterpartiesList.FillChecks(True);
		For Each ItemOfList IN CounterpartiesList Do
			If ItemOfList.Value.IsFolder Then
				ItemOfList.Picture = PictureLib.Folder;
			Else
				ItemOfList.Picture = PictureLib.Attribute;
			EndIf;
		EndDo;
	ElsIf TypeOf(Parameters.CounterpartiesInitialValue) = Type("ValueList") Then
		CounterpartiesList = Parameters.CounterpartiesInitialValue;
	EndIf;
		
	If IsBlankString(Parameters.PrintOptionInitialValue) Then
		If CounterpartiesList.Count() > 1 Or (CounterpartiesList.Count() = 1 AND CounterpartiesList[0].Value.IsFolder) Then
			PrintOption = "List";
		Else
			PrintOption = "Card";
		EndIf;
	Else
		PrintOption = Parameters.PrintOptionInitialValue;
	EndIf;
	
	SendingParameters = New Structure("Subject, Text", "", "");
	
	RefreshContactInformationOnServer();
	Items.Spreadsheet.Edit = True;
	
EndProcedure

// Procedure - event handler ChoiceProcessing.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.PrintFormSaving") Then
		
		If ValueSelected <> Undefined AND ValueSelected <> DialogReturnCode.Cancel Then
			FilesInTemporaryStorage = PlaceSpreadsheetDocumentsToTemporaryStorage(ValueSelected);
			If ValueSelected.SavingVariant = "SaveToFolder" Then
				SavePrintFormsToFolder(FilesInTemporaryStorage, ValueSelected.FolderForSaving);
			EndIf;
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("CommonForm.AttachmentFormatSelection") Then
		
		If ValueSelected <> Undefined AND ValueSelected <> DialogReturnCode.Cancel Then
			AttachmentsList = PlaceSpreadsheetDocumentsToTemporaryStorage(ValueSelected);
			
			NewLettersParameters = New Structure;
			NewLettersParameters.Insert("Subject", SendingParameters.Subject);
			NewLettersParameters.Insert("Text", SendingParameters.Text);
			NewLettersParameters.Insert("Attachments", AttachmentsList);
			
			EmailOperationsClient.CreateNewEmail(NewLettersParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - Save command handler.
//
&AtClient
Procedure Save(Command)
	
	OpenForm("CommonForm.PrintFormSaving", , ThisObject);
	
EndProcedure

// Procedure - Send command handler.
//
&AtClient
Procedure Send(Command)
	
	OpenForm("CommonForm.AttachmentFormatSelection", , ThisObject);
	
EndProcedure

// Procedure - Refresh command handler.
//
&AtClient
Procedure Refresh(Command)
	
	RefreshContactInformationOnServer();
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - OnChange event handler of PrintOption attribute.
//
&AtClient
Procedure PrintOptionOnChange(Item)
	
	RefreshContactInformationOnServer();
	
EndProcedure

// Procedure - Click event handler of the PrintManagement hyperlink.
//
&AtClient
Procedure PrintManagementClick(Item)
	
	NotifyDescription = New NotifyDescription("PrintManagementClickEnd", ThisForm);
	OpenForm("Catalog.Counterparties.Form.ContactInformationFormPrintManagement", , ThisForm,,,,NotifyDescription);
	
EndProcedure

&AtClient
Procedure PrintManagementClickEnd(PrintContentChanged, AdditionalParameters) Export
	
	If PrintContentChanged <> Undefined AND PrintContentChanged Then
		RefreshContactInformationOnServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure updates the contact information depending on the specified settings
//
&AtServer
Procedure RefreshContactInformationOnServer()
	
	CounterpartiesToPrint = GetCounterpartiesToPrint(CounterpartiesList);
	
	If PrintOption = "Card" Then
		Spreadsheet = GeneratePrintedFormCard(CounterpartiesToPrint.UnloadValues());
	ElsIf PrintOption = "List" Then
		Spreadsheet = GeneratePrintableFormList(CounterpartiesToPrint.UnloadValues());
	EndIf;
	
	SetSendingParameters();
	
EndProcedure

// Function generates a tabular document with contact information in the form of counterparties cards
//
// Parameters:
//  Counterparties	 - array - counterparties for which
// contact information is printed Return value:
//  SpreadsheetDocument 
&AtServerNoContext
Function GeneratePrintedFormCard(Counterparties)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ContactInformationCard";
	SpreadsheetDocument.PrintParametersName = "PrintParameters__ContactInformationCard";
	SpreadsheetDocument.PageOrientation = PageOrientation.Portrait;
	SpreadsheetDocument.FitToPage = True;
	
	AreaStructure = FillStructureLayoutRegions("Card");
	SettingsCIContent = LoadSettingsCIContent();
	
	ContactPersonsColumns = 3;
	
	Query = New Query;
	Query.Text = QueryTextContactInformation();
	
	Query.SetParameter("UsedCIKinds", SettingsCIContent.UsedCIKinds);
	Query.SetParameter("CounterpartyTIN", SettingsCIContent.CounterpartyTIN);
	Query.SetParameter("Counterparties", Counterparties);
	
	ResultsArray = Query.ExecuteBatch();
	SelectionCounterparties = ResultsArray[1].Select();
	CISelectionCounterparties = ResultsArray[2].Select();
	SelectionContactPersons = ResultsArray[3].Select();
	CISelectionContactPersons = ResultsArray[4].Select();
	CISelectionIndividual = ResultsArray[5].Select();
	
	SearchForCounterparty = New Structure("Counterparty");
	
	For Each Counterparty IN Counterparties Do
		
		SearchForCounterparty.Counterparty = Counterparty;
		SelectionCounterparties.Reset();
		
		If SelectionCounterparties.FindNext(SearchForCounterparty) Then
			
			TD_Counterparty = New SpreadsheetDocument;
			
			AreaStructure.CounterpartyPresentation.Parameters.Fill(SelectionCounterparties);
			TD_Counterparty.Put(AreaStructure.CounterpartyPresentation);
			AreaStructure.CounterpartyData.Parameters.Fill(SelectionCounterparties);
			TD_Counterparty.Put(AreaStructure.CounterpartyData);
			
			TD_CIKinds_Counterparties = New SpreadsheetDocument;
			TD_ValueCI_Counterparties = New SpreadsheetDocument;
			For Each CIKind IN SettingsCIContent.UsedCIKinds_Counterparties Do
				AreaStructure.CounterpartyCIKind.Parameters.CIKind = CIKind;
				TD_CIKinds_Counterparties.Put(AreaStructure.CounterpartyCIKind);
			EndDo;
			
			CISelectionCounterparties.Reset();
			CurrentStringCI = 0;
			
			While CISelectionCounterparties.FindNext(SearchForCounterparty) Do
				
				StringCIOutput = SettingsCIContent.UsedCIKinds_Counterparties.Find(CISelectionCounterparties.CIKind);
				
				While CurrentStringCI < StringCIOutput Do
					TD_ValueCI_Counterparties.Put(AreaStructure.CounterpartyCIValue);
					CurrentStringCI = CurrentStringCI + 1;
				EndDo;
				
				AreaStructure.CounterpartyCIValue.Parameters.Fill(CISelectionCounterparties);
				TD_ValueCI_Counterparties.Put(AreaStructure.CounterpartyCIValue);
				AreaStructure.CounterpartyCIValue.Parameters.CounterpartyCIValue = "";
				
				CurrentStringCI = CurrentStringCI + 1;
				
			EndDo;
			
			While CurrentStringCI <= SettingsCIContent.UsedCIKinds_Counterparties.UBound() Do
				TD_ValueCI_Counterparties.Put(AreaStructure.CounterpartyCIValue);
				CurrentStringCI = CurrentStringCI + 1;
			EndDo;
			
			TD_Counterparty.Join(TD_CIKinds_Counterparties.GetArea(1,1,TD_CIKinds_Counterparties.TableHeight, TD_CIKinds_Counterparties.TableWidth));
			TD_Counterparty.Join(TD_ValueCI_Counterparties.GetArea(1,1,TD_ValueCI_Counterparties.TableHeight, TD_ValueCI_Counterparties.TableWidth));
			TD_Counterparty.Put(AreaStructure.Indent);
			
			If SettingsCIContent.MainContactPerson Or SettingsCIContent.OtherContactPersons Then
				
				TD_Counterparty.Put(AreaStructure.ContactPersonsTitle);
				
				TD_ContactPersons = New SpreadsheetDocument;
				CurrentColumnContactPersons = 0;
				SelectionContactPersons.Reset();
				
				While SelectionContactPersons.FindNext(SearchForCounterparty) Do
					
					If (SelectionContactPersons.MainOrOtherContactPersons = 1 AND Not SettingsCIContent.MainContactPerson)
						OR (SelectionContactPersons.MainOrOtherContactPersons = 2 AND Not SettingsCIContent.OtherContactPersons) Then
							Continue;
					EndIf;
					
					TD_ContactPerson = New SpreadsheetDocument;
					AreaStructure.ContactPerson.Parameters.Fill(SelectionContactPersons);
					TD_ContactPerson.Put(AreaStructure.ContactPerson);
					CurrentColumnContactPersons = CurrentColumnContactPersons + 1;
						
					SearchByContactPerson = New Structure("ContactPerson", SelectionContactPersons.ContactPerson);
					CurrentStringCI = 0;
					CISelectionContactPersons.Reset();
					
					While CISelectionContactPersons.FindNext(SearchByContactPerson) Do
						AreaStructure.ContactPersonCI.Parameters.Fill(CISelectionContactPersons);
						TD_ContactPerson.Put(AreaStructure.ContactPersonCI);
						CurrentStringCI = CurrentStringCI + 1;
					EndDo;
					
					AreaStructure.ContactPersonCI.Parameters.ContactPersonCIValue = "";
					While CurrentStringCI < SettingsCIContent.UsedCIKinds_ContactPersons.Count() Do
						TD_ContactPerson.Put(AreaStructure.ContactPersonCI);
						CurrentStringCI = CurrentStringCI + 1;
					EndDo;
					
					If SelectionContactPersons.MainOrOtherContactPersons = 1 Then
						Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
						Area = TD_ContactPerson.Area(1,2,TD_ContactPerson.TableHeight, TD_ContactPerson.TableWidth);
						Area.Outline(Line, Line, Line, Line);
					EndIf;
					
					If CurrentColumnContactPersons % ContactPersonsColumns = 1 Then
						TD_ContactPersons.Put(AreaStructure.IndentCP);
						TD_ContactPersons.Put(TD_ContactPerson.GetArea(1,1,TD_ContactPerson.TableHeight, TD_ContactPerson.TableWidth));
					Else 
						TD_ContactPersons.Join(TD_ContactPerson.GetArea(1,1,TD_ContactPerson.TableHeight, TD_ContactPerson.TableWidth));
					EndIf;
					
				EndDo;
				
				AreaStructure.ContactPerson.Parameters.ContactPersonPresentation = "";
				AddingEmptyColumnsContactPersons = ContactPersonsColumns - (CurrentColumnContactPersons % (ContactPersonsColumns + 1));
				ContactPersonsEmptyColumnsDisplayed = 0;
				While ContactPersonsEmptyColumnsDisplayed < AddingEmptyColumnsContactPersons Do
					TD_ContactPersons.Join(AreaStructure.ContactPerson);
					ContactPersonsEmptyColumnsDisplayed = ContactPersonsEmptyColumnsDisplayed + 1;
				EndDo;
				
				TD_Counterparty.Put(TD_ContactPersons.GetArea(1,1,TD_ContactPersons.TableHeight, TD_ContactPersons.TableWidth));
				
			EndIf;
			
			If SettingsCIContent.ResponsibleManager Then
				
				SearchForResponsible = New Structure("Ind", SelectionCounterparties.Ind);
				CISelectionIndividual.Reset();
				
				If CISelectionIndividual.FindNext(SearchForResponsible) Then
					AreaStructure.Responsible.Parameters.Fill(CISelectionIndividual);
				Else
					AreaStructure.Responsible.Parameters.ResponsiblePersonPhone = "";
				EndIf;
				
				AreaStructure.Responsible.Parameters.Fill(SelectionCounterparties);
				
				TD_Counterparty.Put(AreaStructure.Indent);
				TD_Counterparty.Put(AreaStructure.Responsible);
				
			EndIf;
			
			If Not SpreadsheetDocument.CheckPut(TD_Counterparty) Then
				SpreadsheetDocument.PutHorizontalPageBreak();
			EndIf;
			
			SpreadsheetDocument.Put(TD_Counterparty);
			SpreadsheetDocument.Put(AreaStructure.IndentWithUnderline);
			
		EndIf;
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function generates a tabular document with contact information in the form of counterparties list
//
// Parameters:
//  Counterparties	 - array - counterparties for which
// contact information is printed Return value:
//  SpreadsheetDocument 
&AtServerNoContext
Function GeneratePrintableFormList(Counterparties)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ContactInformationList";
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS__ContactInformationList";
	SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	
	AreaStructure = FillStructureLayoutRegions("List");
	SettingsCIContent = LoadSettingsCIContent();
	
	Query = New Query;
	Query.Text = QueryTextContactInformation();
	Query.Text = Query.Text + "
       |;
       |	
       |////////////////////////////////////////////////////////////////////////////////
       |SELECT
       |	MAX(NestedSelect.ContactPersonsCount) AS ContactPersonsCount
       |FROM
       |	(SELECT
       |		ContactPersons.Owner AS Counterparty,
       |		COUNT(DISTINCT ContactPersons.Ref) AS ContactPersonsCount
       |	FROM
       |		Catalog.ContactPersons AS ContactPersons
       |	WHERE
       |		ContactPersons.Owner IN(&Counterparties)
       |		AND ContactPersons.DeletionMark = FALSE
       |	
       |	GROUP BY
       |		ContactPersons.Owner) AS NestedSelect";
		
	Query.SetParameter("UsedCIKinds", SettingsCIContent.UsedCIKinds);
	Query.SetParameter("CounterpartyTIN", SettingsCIContent.CounterpartyTIN);
	Query.SetParameter("Counterparties", Counterparties);
	
	ResultsArray = Query.ExecuteBatch();
	SelectionCounterparties = ResultsArray[1].Select();
	CISelectionCounterparties = ResultsArray[2].Select();
	SelectionContactPersons = ResultsArray[3].Select();
	CISelectionContactPersons = ResultsArray[4].Select();
	CISelectionIndividual = ResultsArray[5].Select();
	SelectionOfContactPersonsMaxCount = ResultsArray[6].Select();
	
	SelectionOfContactPersonsMaxCount.Next();
	ContactPersonsColumns = ?(SelectionOfContactPersonsMaxCount.ContactPersonsCount = NULL, 0, SelectionOfContactPersonsMaxCount.ContactPersonsCount);
	If SettingsCIContent.MainContactPerson AND Not SettingsCIContent.OtherContactPersons Then
		ContactPersonsColumns = 1;
	ElsIf Not SettingsCIContent.MainContactPerson AND SettingsCIContent.OtherContactPersons Then
		ContactPersonsColumns = ContactPersonsColumns - 1;
	ElsIf Not SettingsCIContent.MainContactPerson AND Not SettingsCIContent.OtherContactPersons Then
		ContactPersonsColumns = 0;
	EndIf;
	
	// HEADER
	SpreadsheetDocument.Put(AreaStructure.CounterpartyTitle);
	
	For Each CIKind IN SettingsCIContent.UsedCIKinds_Counterparties Do
		Area = AreaStructure.CIKindTitle.Area(1,2,1,2);
		If CIKind.Type = Enums.ContactInformationTypes.Address Then
			Area.ColumnWidth = 25;
		Else
			Area.ColumnWidth = 14.5;
		EndIf;
		AreaStructure.CIKindTitle.Parameters.CIKind = CIKind;
		SpreadsheetDocument.Join(AreaStructure.CIKindTitle);
	EndDo;
	
	For IndexOf = 1 To ContactPersonsColumns Do
		SpreadsheetDocument.Join(AreaStructure.ContactPersonTitle);
	EndDo;
	
	If SettingsCIContent.ResponsibleManager Then
		SpreadsheetDocument.Join(AreaStructure.ResponsiblePersonTitle);
	EndIf;
	
	CounterpartyRecordNo = 0;
	SearchForCounterparty = New Structure("Counterparty");
	
	// DATA
	For Each Counterparty IN Counterparties Do
		
		SearchForCounterparty.Counterparty = Counterparty;
		SelectionCounterparties.Reset();
		
		If SelectionCounterparties.FindNext(SearchForCounterparty) Then
			
			CounterpartyRecordNo = CounterpartyRecordNo + 1;
			TD_Counterparty = New SpreadsheetDocument;
			
			AreaStructure.CounterpartyData.Parameters.Fill(SelectionCounterparties);
			TD_Counterparty.Put(AreaStructure.CounterpartyData);
			
			CISelectionCounterparties.Reset();
			CurrentColumnOutput = 0;
			
			While CISelectionCounterparties.FindNext(SearchForCounterparty) Do
				
				DisplayColumn = SettingsCIContent.UsedCIKinds_Counterparties.Find(CISelectionCounterparties.CIKind);
				While CurrentColumnOutput < DisplayColumn Do
					TD_Counterparty.Join(AreaStructure.CIData);
					CurrentColumnOutput = CurrentColumnOutput + 1;
				EndDo;
				
				AreaStructure.CIData.Parameters.Fill(CISelectionCounterparties);
				TD_Counterparty.Join(AreaStructure.CIData);
				AreaStructure.CIData.Parameters.CounterpartyCIValue = "";
				CurrentColumnOutput = CurrentColumnOutput + 1;
				
			EndDo;
			
			While CurrentColumnOutput <= SettingsCIContent.UsedCIKinds_Counterparties.UBound() Do
				TD_Counterparty.Join(AreaStructure.CIData);
				CurrentColumnOutput = CurrentColumnOutput + 1;
			EndDo;
			
			If SettingsCIContent.MainContactPerson Or SettingsCIContent.OtherContactPersons Then
				
				SelectionContactPersons.Reset();
				CurrentColumnOutput = 0;
				
				While SelectionContactPersons.FindNext(SearchForCounterparty) Do
					
					If (SelectionContactPersons.MainOrOtherContactPersons = 1 AND Not SettingsCIContent.MainContactPerson)
						OR (SelectionContactPersons.MainOrOtherContactPersons = 2 AND Not SettingsCIContent.OtherContactPersons) Then
							Continue;
						EndIf;
						
					TD_ContactPerson = New SpreadsheetDocument;
					
					AreaStructure.ContactPersonPresentation.Parameters.Fill(SelectionContactPersons);
					TD_ContactPerson.Put(AreaStructure.ContactPersonPresentation);
					
					SearchByContactPerson = New Structure("ContactPerson", SelectionContactPersons.ContactPerson);
					CISelectionContactPersons.Reset();
					
					While CISelectionContactPersons.FindNext(SearchByContactPerson) Do
						
						AreaStructure.ContactPersonCIValue.Parameters.Fill(CISelectionContactPersons);
						TD_ContactPerson.Put(AreaStructure.ContactPersonCIValue);
						
					EndDo;
					
					CurrentColumnOutput = CurrentColumnOutput + 1;
					TD_Counterparty.Join(TD_ContactPerson.GetArea(1,1,TD_ContactPerson.TableHeight, TD_ContactPerson.TableWidth));
					
				EndDo;
				
				AreaStructure.CIData.Parameters.CounterpartyCIValue = "";
				While CurrentColumnOutput < ContactPersonsColumns Do
					TD_Counterparty.Join(AreaStructure.CIData);
					CurrentColumnOutput = CurrentColumnOutput + 1;
				EndDo;
				
			EndIf;
			
			If SettingsCIContent.ResponsibleManager Then
				
				SearchForResponsible = New Structure("Ind", SelectionCounterparties.Ind);
				CISelectionIndividual.Reset();
				
				If CISelectionIndividual.FindNext(SearchForResponsible) Then
					AreaStructure.ResponsibleData.Parameters.Fill(CISelectionIndividual);
				Else
					AreaStructure.ResponsibleData.Parameters.ResponsiblePersonPhone = "";
				EndIf;
				
				AreaStructure.ResponsibleData.Parameters.Fill(SelectionCounterparties);
				TD_Counterparty.Join(AreaStructure.ResponsibleData);
				
			EndIf;
			
			TD_Counterparty.Put(AreaStructure.Indent);
			
			If CounterpartyRecordNo % 2 = 0 Then
				Area = TD_Counterparty.Area(1,1,TD_Counterparty.TableHeight, TD_Counterparty.TableWidth);
				Area.BackColor = New Color(245, 251, 247);
			EndIf;
			
			If Not SpreadsheetDocument.CheckPut(TD_Counterparty) Then
				SpreadsheetDocument.PutHorizontalPageBreak();
			EndIf;
			
			SpreadsheetDocument.Put(TD_Counterparty);
			
		EndIf;
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Procedure sets default values for sending email
//
&AtServer
Procedure SetSendingParameters()
	
	SendingParameters.Subject = "Counterparty contact information (" + PrintOption + ")" + " on " + Format(CurrentSessionDate(), "DF=MM/dd/yyyy")
		+ ". Generated " + UsersClientServer.AuthorizedUser() + ".";
	
EndProcedure

// Function gets the counterparties for printing contact information.
//
// Parameters:
//  CounterpartiesList	 - ValueList	 - Counterparty list may contain catalog items and groups.
// Returns:
//  ValueList - List of contractors, contains only items. Available groups are expanded to items.
&AtServerNoContext
Function GetCounterpartiesToPrint(CounterpartiesList)
	
	CounterpartiesToPrint = New ValueList;
	Counterparties = CommonUseClientServer.GetArrayOfMarkedListItems(CounterpartiesList);
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Counterparties.Ref AS Counterparty
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.Ref IN HIERARCHY(&Refs)
		|	AND Counterparties.DeletionMark = FALSE
		|	AND Counterparties.IsFolder = FALSE
		|
		|ORDER BY
		|	Counterparties.Description";

	// It is required to be run in loop to save the specified sorting
	For Each Counterparty IN Counterparties Do
		If Counterparty.IsFolder Then
			Query.SetParameter("Ref", Counterparty);
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				CounterpartiesToPrint.Add(Selection.Counterparty);
			EndDo;
		Else
			CounterpartiesToPrint.Add(Counterparty);
		EndIf;
	EndDo;
		
	Return CounterpartiesToPrint;
	
EndFunction

// Function returns a query text for counterparties, contact persons and responsible person with all contact information
//
&AtServerNoContext
Function QueryTextContactInformation()
	
	QueryText = "
		|SELECT
		|	Counterparties.Ref AS Counterparty,
		|	Counterparties.Presentation AS CounterpartyPresentation,
		|	Counterparties.DescriptionFull AS DescriptionFull,
		|	CASE
		|		WHEN &CounterpartyTIN = TRUE
		|			THEN ""TIN "" + Counterparties.TIN
		|		ELSE """"
		|	END AS TINPresentation,
		|	Counterparties.LegalEntityIndividual AS LegalEntityIndividual,
		|	Counterparties.Responsible AS ResponsibleManager,
		|	Counterparties.Responsible.Presentation AS ResponsiblePresentation,
		|	Counterparties.Responsible.Ind AS Ind
		|INTO vtCounterparties
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.Ref IN(&Counterparties)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	vtCounterparties.Counterparty,
		|	vtCounterparties.CounterpartyPresentation,
		|	vtCounterparties.DescriptionFull,
		|	vtCounterparties.TINPresentation,
		|	vtCounterparties.LegalEntityIndividual,
		|	vtCounterparties.ResponsibleManager,
		|	vtCounterparties.ResponsiblePresentation,
		|	vtCounterparties.Ind
		|FROM
		|	vtCounterparties AS vtCounterparties
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CounterpartiesContactInformation.Ref AS Counterparty,
		|	CounterpartiesContactInformation.Type AS CIKind,
		|	CounterpartiesContactInformation.Presentation AS CounterpartyCIValue
		|FROM
		|	Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
		|WHERE
		|	CounterpartiesContactInformation.Ref IN(&Counterparties)
		|	AND CounterpartiesContactInformation.Type IN(&UsedCIKinds)
		|
		|ORDER BY
		|	CounterpartiesContactInformation.Kind.AdditionalOrderingAttribute
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactPersons.Owner AS Counterparty,
		|	ContactPersons.Ref AS ContactPerson,
		|	ContactPersons.Presentation AS ContactPersonPresentation,
		|	CASE
		|		WHEN ContactPersons.Ref = ContactPersons.Owner.ContactPerson
		|			THEN 1
		|		ELSE 2
		|	END AS MainOrOtherContactPersons
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.Owner IN(&Counterparties)
		|	AND ContactPersons.DeletionMark = FALSE
		|
		|ORDER BY
		|	MainOrOtherContactPersons
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactPersonsContactInformation.Ref.Owner AS Counterparty,
		|	ContactPersonsContactInformation.Ref AS ContactPerson,
		|	ContactPersonsContactInformation.Type AS CIKind,
		|	ContactPersonsContactInformation.Presentation AS ContactPersonCIValue
		|FROM
		|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
		|WHERE
		|	ContactPersonsContactInformation.Ref.Owner IN(&Counterparties)
		|	AND ContactPersonsContactInformation.Type IN(&UsedCIKinds)
		|	AND ContactPersonsContactInformation.Ref.DeletionMark = FALSE
		|
		|ORDER BY
		|	ContactPersonsContactInformation.Kind.AdditionalOrderingAttribute
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IndividualsContactInformation.Ref AS Ind,
		|	IndividualsContactInformation.Type AS CIKind,
		|	IndividualsContactInformation.Presentation AS ResponsiblePersonPhone
		|FROM
		|	Catalog.Individuals.ContactInformation AS IndividualsContactInformation
		|WHERE
		|	IndividualsContactInformation.Ref In
		|			(SELECT DISTINCT
		|				vtCounterparties.Ind
		|			FROM
		|				vtCounterparties)
		|	AND IndividualsContactInformation.Type IN(&UsedCIKinds)
		|	AND IndividualsContactInformation.Ref.DeletionMark = FALSE
		|
		|ORDER BY
		|	IndividualsContactInformation.Kind.AdditionalOrderingAttribute";
				   
	Return QueryText;
	
EndFunction

// Function returns the printing content settings for
// current user First all existing kinds of contact information are formed and then user settings are applied  to them.
//
// Returns:
//  Structure - Structure fields:
// 		UsedCIKinds - array of all kinds of contact
// 		information to be printed, UsedCIKinds_Counterparties - array of the kinds of counterparties contact
// 		information to be printed, CounterpartyTIN - output flag of
// 		the counterparty TIN, MainContactPerson - output flag of the
// 		main contact person, OtherContactPersons - output flag of other
// 		contact persons, ResponsibleManager - output flag of responsible manager.
&AtServerNoContext
Function LoadSettingsCIContent()
	
	SettingsCIContent = New Structure;
	SettingsCIContent.Insert("UsedCIKinds", New Array);
	SettingsCIContent.Insert("UsedCIKinds_Counterparties", New Array);
	SettingsCIContent.Insert("UsedCIKinds_ContactPersons", New Array);
	SettingsCIContent.Insert("CounterpartyTIN");
	SettingsCIContent.Insert("MainContactPerson");
	SettingsCIContent.Insert("OtherContactPersons");
	SettingsCIContent.Insert("ResponsibleManager");
	
	Selection = SmallBusinessServer.GetAvailableForPrintingCIKinds().Select();
	
	UsedCIKinds = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
	"UsedCIKinds", New Map);
	
	While Selection.Next() Do
		
		UseCI = UsedCIKinds.Get(Selection.CIKind);
		
		// If there is no available kind of contact information in saved user settings, then we set usage by default
		If UseCI = Undefined Then
			UseCI = SmallBusinessServer.SetPrintDefaultCIKind(Selection.CIKind);
		EndIf;
		
		If UseCI Then
			SettingsCIContent.UsedCIKinds.Add(Selection.CIKind);
			If Selection.CIKind.Parent = Catalogs.ContactInformationTypes.CatalogCounterparties Then
				SettingsCIContent.UsedCIKinds_Counterparties.Add(Selection.CIKind);
			ElsIf Selection.CIKind.Parent = Catalogs.ContactInformationTypes.CatalogContactPersons Then
				SettingsCIContent.UsedCIKinds_ContactPersons.Add(Selection.CIKind);
			EndIf;
		EndIf;
		
	EndDo;
	
	SettingsCIContent.CounterpartyTIN = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"CounterpartyTIN", True);
		
	SettingsCIContent.MainContactPerson = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"MainContactPerson", True);
		
	SettingsCIContent.OtherContactPersons = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"OtherContactPersons", True);
		
	SettingsCIContent.ResponsibleManager = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"ResponsibleManager", True);
		
	Return SettingsCIContent;
		
EndFunction

&AtServerNoContext
// Function returns the structure of the layout areas for generating contact information
//
Function FillStructureLayoutRegions(PrintOption)
	
	AreaStructure = New Structure;
	
	If PrintOption = "Card" Then
		
		Template = PrintManagement.PrintedFormsTemplate("Catalog.Counterparties.PF_MXL_ContactInformationCard");
		
		IndentWithUnderline = Template.GetArea("Indent");
		Line = New Line(SpreadsheetDocumentCellLineType.ThinDashed, 3);
		Area = IndentWithUnderline.Area(1,1,IndentWithUnderline.TableHeight, IndentWithUnderline.TableWidth);
		Area.BorderColor = StyleColors.BorderColor;
		Area.Outline(,,,Line);
		
		AreaStructure.Insert("IndentWithUnderline",	  IndentWithUnderline);
		AreaStructure.Insert("Indent",				  Template.GetArea("Indent"));
		AreaStructure.Insert("CounterpartyPresentation", Template.GetArea("CounterpartyPresentation"));
		AreaStructure.Insert("CounterpartyData",		  Template.GetArea("CounterpartyData"));
		AreaStructure.Insert("CounterpartyCIKind",	  	  Template.GetArea("CounterpartyCIKind"));
		AreaStructure.Insert("CounterpartyCIValue",	  Template.GetArea("CounterpartyCIValue"));
		AreaStructure.Insert("ContactPersonsTitle", Template.GetArea("ContactPersonsTitle"));
		AreaStructure.Insert("ContactPerson", 		  Template.GetArea("ContactPerson"));
		AreaStructure.Insert("ContactPersonCI", 		  Template.GetArea("ContactPersonCI"));
		AreaStructure.Insert("IndentCP", 		  		  Template.GetArea("IndentCP"));
		AreaStructure.Insert("Responsible",			  Template.GetArea("Responsible"));
		
	ElsIf PrintOption = "List" Then
		
		Template = PrintManagement.PrintedFormsTemplate("Catalog.Counterparties.PF_MXL_ContactInformationList");
	
		AreaStructure.Insert("CounterpartyTitle", 		  Template.GetArea("CounterpartyTitle"));
		AreaStructure.Insert("CIKindTitle",	  		  Template.GetArea("CIKindTitle"));
		AreaStructure.Insert("ContactPersonTitle", 	  Template.GetArea("ContactPersonTitle"));
		AreaStructure.Insert("ResponsiblePersonTitle", 	  Template.GetArea("ResponsiblePersonTitle"));
		AreaStructure.Insert("CounterpartyData",	  		  Template.GetArea("CounterpartyData"));
		AreaStructure.Insert("CIData", 			  		  Template.GetArea("CIData"));
		AreaStructure.Insert("ContactPersonPresentation", Template.GetArea("ContactPersonPresentation"));
		AreaStructure.Insert("ContactPersonCIValue", 	  Template.GetArea("ContactPersonCIValue"));
		AreaStructure.Insert("ResponsibleData", 		  Template.GetArea("ResponsibleData"));
		AreaStructure.Insert("Indent",			  		  Template.GetArea("Indent"));
		
	EndIf;
	                                                                           
	Return AreaStructure;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsSaveAndSend

&AtServer
Function PlaceSpreadsheetDocumentsToTemporaryStorage(SavingSettings)
	Var ZipFileWriter, ArchiveName;
	
	Result = New Array;
	
	// preparation of the archive
	If SavingSettings.PackIntoArchive Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	// preparation of temporary folders
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	UsedFilesNames = New Map;
	
	SelectedSavingFormats = SavingSettings.SavingFormats;
	FormatsTable = PrintManagement.SpreadsheetDocumentSavingFormatsSettings();
	
	// saving print forms
	PrintForm = Spreadsheet;
	
	If PrintForm.TableHeight = 0 Then
		Return Result;
	EndIf;
	
	For Each FileType IN SelectedSavingFormats Do
		FormatSettings = FormatsTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
		
		FileName = GetTempFileNameForPrintForm("Contact information (" + PrintOption + ")", FormatSettings.Extension, UsedFilesNames);
		FullFileName = UniqueFileName(CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + FileName);
		
		PrintForm.Write(FullFileName, FileType);
		
		If FileType = SpreadsheetDocumentFileType.HTML Then
			InsertImagesToHTML(FullFileName);
		EndIf;
		
		If ZipFileWriter <> Undefined Then
			ZipFileWriter.Add(FullFileName);
		Else
			BinaryData = New BinaryData(FullFileName);
			PathInTemStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
			FileDescription = New Structure;
			FileDescription.Insert("Presentation", FileName);
			FileDescription.Insert("AddressInTemporaryStorage", PathInTemStorage);
			If FileType = SpreadsheetDocumentFileType.ANSITXT Then
				FileDescription.Insert("Encoding", "windows-1251");
			EndIf;
			Result.Add(FileDescription);
		EndIf;
	EndDo;
	
	// if the archive is prepared, we write and place it into temporary storage
	If ZipFileWriter <> Undefined Then
		ZipFileWriter.Write();
		FileOfArchive = New File(ArchiveName);
		BinaryData = New BinaryData(ArchiveName);
		PathInTemStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
		FileDescription = New Structure;
		FileDescription.Insert("Presentation", "Contact information " + "(" + PrintOption + ")" + ".zip");
		FileDescription.Insert("AddressInTemporaryStorage", PathInTemStorage);
		Result.Add(FileDescription);
	EndIf;
	
	DeleteFiles(TempFolderName);
	
	Return Result;
	
EndFunction

&AtServer
Function GetTempFileNameForPrintForm(TemplateName, Extension, UsedFilesNames)
	
	FileNamePattern = "%1%2.%3";
	
	TempFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(
		StringFunctionsClientServer.PlaceParametersIntoString(FileNamePattern, TemplateName, "", Extension));
		
	UsageNumber = ?(UsedFilesNames[TempFileName] <> Undefined,
							UsedFilesNames[TempFileName] + 1,
							1);
	
	UsedFilesNames.Insert(TempFileName, UsageNumber);
	
	// If the name has been previously used, we add counter at the end of the name
	If UsageNumber > 1 Then
		TempFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(
			StringFunctionsClientServer.PlaceParametersIntoString(
				FileNamePattern,
				TemplateName,
				" (" + UsageNumber + ")",
				Extension));
	EndIf;
	
	Return TempFileName;
	
EndFunction

&AtServer
Procedure InsertImagesToHTML(HTMLFileName)
	
	TextDocument = New TextDocument();
	TextDocument.Read(HTMLFileName, TextEncoding.UTF8);
	HTMLText = TextDocument.GetText();
	
	HTMLFile = New File(HTMLFileName);
	
	ImagesFolderName = HTMLFile.BaseName + "_files";
	PathToImagesFolder = StrReplace(HTMLFile.DescriptionFull, HTMLFile.Name, ImagesFolderName);
	
	// it is expected that the directory will contain images only
	ImageFiles = FindFiles(PathToImagesFolder, "*");
	
	For Each PictureFile IN ImageFiles Do
		ImageAsText = Base64String(New BinaryData(PictureFile.DescriptionFull));
		ImageAsText = "data:image/" + Mid(PictureFile.Extension,2) + ";base64," + Chars.LF + ImageAsText;
		
		HTMLText = StrReplace(HTMLText, ImagesFolderName + "\" + PictureFile.Name, ImageAsText);
	EndDo;
		
	TextDocument.SetText(HTMLText);
	TextDocument.Write(HTMLFileName, TextEncoding.UTF8);
	
EndProcedure

&AtClient
Procedure SavePrintFormsToFolder(FilesListInTempStorage, Val Folder = "")
	
	#If WebClient Then
		For Each FileToSave IN FilesListInTempStorage Do
			GetFile(FileToSave.AddressInTemporaryStorage, FileToSave.Presentation);
		EndDo;
		Return;
	#EndIf
	
	Folder = CommonUseClientServer.AddFinalPathSeparator(Folder);
	For Each FileToSave IN FilesListInTempStorage Do
		BinaryData = GetFromTempStorage(FileToSave.AddressInTemporaryStorage);
		BinaryData.Write(UniqueFileName(Folder + FileToSave.Presentation));
	EndDo;
	
	Status(NStr("en='Saving has been successfully completed.';ru='Сохранение успешно завершено.'"), , NStr("en='to folder:';ru='в папку:'") + " " + Folder);
	
EndProcedure

&AtClientAtServerNoContext
Function UniqueFileName(FileName)
	
	File = New File(FileName);
	BaseName = File.BaseName;
	Extension = File.Extension;
	Folder = File.Path;
	
	Counter = 1;
	While File.Exist() Do
		Counter = Counter + 1;
		File = New File(Folder + BaseName + " (" + Counter + ")" + Extension);
	EndDo;
	
	Return File.DescriptionFull;
	
EndFunction

#EndRegion


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
