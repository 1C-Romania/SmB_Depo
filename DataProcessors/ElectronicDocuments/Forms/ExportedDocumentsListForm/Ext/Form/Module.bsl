////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
Procedure GetEDToView(DataRow)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FullFileName");
	ParametersStructure.Insert("FileDescription");
	ParametersStructure.Insert("EDDirection");
	ParametersStructure.Insert("Counterparty");
	ParametersStructure.Insert("UUID");
	ParametersStructure.Insert("EDOwner");
	ParametersStructure.Insert("ElectronicDocument");
	ParametersStructure.Insert("StorageAddress");
	ParametersStructure.Insert("FileOfArchive");
	FillPropertyValues(ParametersStructure, DataRow);
	If ValueIsFilled(ParametersStructure.ElectronicDocument) Then
		FormParameters = New Structure;
		FormParameters.Insert("ElectronicDocument", ParametersStructure.ElectronicDocument);
		FormParameters.Insert("EDOwner",          ParametersStructure.EDOwner);
		OpenForm("DataProcessor.ElectronicDocuments.Form.EDViewImportForm", FormParameters, ThisObject);
	Else
		OpenForm("DataProcessor.ElectronicDocuments.Form.EDViewImportForm",
			New Structure("EDStructure", ParametersStructure), ThisObject, ParametersStructure.UUID);
	EndIf;
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure DataTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	GetEDToView(DataTable[SelectedRow]);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	EDArrayStructure = "";
	If Parameters.Property("EDStructure", EDArrayStructure) Then
		For Each ExchangeStructure IN EDArrayStructure Do
			NewRow = DataTable.Add();
			FillPropertyValues(NewRow, ExchangeStructure);
			If ValueIsFilled(NewRow.ElectronicDocument) Then
				NewRow.EDPresentation = ElectronicDocumentsService.GetEDPresentation(NewRow.ElectronicDocument);
			Else
				NewRow.EDPresentation = NewRow.FileDescription;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("EDRefsArray", EDArrayStructure) Then
		Map = CommonUse.ObjectAttributeValues(EDArrayStructure, "FileOwner, EDDirection");
		For Each KeyAndValue IN Map Do
			NewRow = DataTable.Add();
			NewRow.ElectronicDocument = KeyAndValue.Key;
			NewRow.EDOwner = KeyAndValue.Value.FileOwner;
			NewRow.EDDirection = KeyAndValue.Value.EDDirection;
			NewRow.EDPresentation = ElectronicDocumentsService.GetEDPresentation(NewRow.ElectronicDocument);
		EndDo;
	EndIf;
	
EndProcedure





