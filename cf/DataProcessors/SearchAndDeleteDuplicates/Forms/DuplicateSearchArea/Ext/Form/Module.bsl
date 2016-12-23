// Parameters are awaited:
//
//     DuplicateSearchArea - String - Metadata full name of previously selected search area table.
//
// Returned as a selection result:
//
//     Undefined - Reject editing.
//     String       - Address of a temporary storage of new linker settings.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("DuplicateSearchArea", AreaDefault);
	
	InitializeDuplicatesSearchAreasList();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DuplicateSearchAreasSelection(Item, SelectedRow, Field, StandardProcessing)
	
	MakeSelection(SelectedRow);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	
	MakeSelection(Items.DuplicateSearchAreas.CurrentRow);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure MakeSelection(Val RowID)
	
	Item = DuplicateSearchAreas.FindByID(RowID);
	If Item = Undefined Then
		Return;
		
	ElsIf Item.Value = AreaDefault Then
		// There were no changes
		Close();
		Return;
		
	EndIf;
	
	NotifyChoice(Item.Value);
EndProcedure

&AtServer
Procedure InitializeDuplicatesSearchAreasList()
	
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.DuplicateSearchAreas(DuplicateSearchAreas);
	
	DuplicateSearchAreas.SortByPresentation();
	Item = DuplicateSearchAreas.FindByValue(AreaDefault);
	If Item<>Undefined Then
		Items.DuplicateSearchAreas.CurrentRow = Item.GetID();
	EndIf;
	
EndProcedure


#EndRegion













