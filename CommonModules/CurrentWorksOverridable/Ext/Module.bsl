////////////////////////////////////////////////////////////////////////////////
// The Current ToDos subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Fills out a list of the current works handlers.
//
// Parameters:
//  Handlers - Array - the array of references to manager modules or general
//                         modules which define the AtFillingToDoList procedure.
//
Procedure AtDeterminingCurrentWorksHandlers(Handlers) Export
	
	
	
EndProcedure

// Gets the list of command interface sections in the specified order.
//
// Parameters:
//  Sections - Array - the command interface sections array.
//                     Sets the initial order of sections on the current works bar.
//
Procedure AtDeterminingCommandInterfaceSectionsOrder(Sections) Export
	
	
	
EndProcedure

// Disables current works.
//
// Parameters:
//  DisabledWork - Array - the array with rows of identifiers of current works which have to be disabled.
//
Procedure AtCurrentWorksDisable(DisabledWork) Export
	
EndProcedure

// Sets general parameters of queries for current works calculation.See
// CurrentWorksService.SetCommonQueryParameters().
//
// Parameters:
//  Query - running query.
//  CommonQueryParameters - Structure - general values for calculation of current works.
//
Procedure SetCommonQueryParameters(Query, CommonQueryParameters) Export
	
EndProcedure

// The procedure-handler called up in the form of the current works details.
// It sets form opening parameters and necessary form list filters.
//
// Parameters:
//  Form - ControllableForm
//  list - DynamicList
//
Procedure OnCreateAtServer(Form, List) Export
	
EndProcedure

// The procedure-handler called up in the form of the current works details.
// It allows replacing saved values of form attributes.
// It replaces saved values of form attributes with the properties Form.Parameters.QuickFilterStructure.
//
// Parameters:
//  Form - ControllableForm
//  Settings - Map
//
Procedure BeforeImportDataFromSettingsAtServer(Form, Settings) Export
	
EndProcedure

#EndRegion