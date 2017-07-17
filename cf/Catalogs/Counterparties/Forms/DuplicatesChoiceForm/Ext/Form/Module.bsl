////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DoublesList.Parameters.SetParameterValue("TIN", TrimAll(Parameters.TIN));
	
	ThisForm.Title =  NStr("en='TIN duplicate list';ru='Список дублей по ИНН'");
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure DuplicatesListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	TransferParameters = New Structure("Key", Item.CurrentData.Ref);
	TransferParameters.Insert("CloseOnOwnerClose", True);
	
	OpenForm("Catalog.Counterparties.ObjectForm",
				  TransferParameters, 
				  Item,
				  ,
				  ,
				  ,
				  New NotifyDescription("HandleItemEdit", ThisForm));
	
EndProcedure
			  
&AtClient
Procedure DoublesListOnActivateRow(Item)
	
	DataCurrentRows = Items.DoublesList.CurrentData;
	
	If Not DataCurrentRows = Undefined Then
		
		AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenDocumentsOnCounterparty(Command)
	
	CurrentDataOfList = Items.DoublesList.CurrentData;
	If CurrentDataOfList = Undefined Then
		WarningText = NStr("en='Command cannot be executed for the specified object.';ru='Команда не может быть выполнена для указанного объекта!'");
		ShowMessageBox(Undefined, WarningText);
		Return;
	EndIf;
	
	FilterStructure = New Structure("Counterparty", CurrentDataOfList.Ref);
	FormParameters = New Structure("SettingsKey, Filter, GenerateOnOpen", "Counterparty", FilterStructure, True);
	
	OpenForm("DataProcessor.DocumentsByCounterparty.Form.DocumentsByCounterparty", FormParameters, ThisForm,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure HandleItemEdit(ClosingResult, AdditionalParameters) Export
	Items.DoublesList.Refresh();
EndProcedure

// Procedure of the list string activation processor.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	CurrentDataOfList = Items.DoublesList.CurrentData;
	If CurrentDataOfList = Undefined Then
		Return;
	EndIf;
	
	Items.OpenDocumentsOnCounterparty.Title = "Documents on counterparty (" + GetCounterpartyDocumentsCount(CurrentDataOfList.Ref) + ")";
	
EndProcedure // HandleListStringActivation()

&AtServerNoContext
Function GetCounterpartyDocumentsCount(Counterparty)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	COUNT(DISTINCT DocumentsByCounterparty.Ref) AS DocumentsCount
		|FROM
		|	FilterCriterion.DocumentsByCounterparty(&Counterparty) AS DocumentsByCounterparty";

	Query.SetParameter("Counterparty", Counterparty);

	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return 0;
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.DocumentsCount;
	EndIf;

EndFunction
