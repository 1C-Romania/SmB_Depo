////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data exchange in the service model".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Event handler of the OnReadAtServer form that is
// built into the forms of the data items
// (catalogs items, documents, registers records, etc.)
// to lock the form if it is an attempt to change the undivided data,
// derived from the application at the offline workplace.
//
// Parameters:
//  CurrentObject - An object that is read
//  ReadOnly - Boolean - ViewOnly property of the form
//
Procedure ObjectOnReadAtServer(CurrentObject, ReadOnly) Export
	
	If Not ReadOnly Then
		
		MetadataObject = Metadata.FindByType(TypeOf(CurrentObject));
		OfflineWorkService.DetermineWhetherChangesData(MetadataObject, ReadOnly);
		
	EndIf;
	
EndProcedure

#EndRegion
