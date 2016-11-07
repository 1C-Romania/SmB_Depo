///////////////////////////////////////////////////////////////////////////////////
// SaaSOverridable.
//
///////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Called when deleting a data area.
// IN the procedure you should delete data field
// data that can not be deleted with the standard mechanism.
//
// Parameters:
// DataArea - Separator value type - value
// of a separator of the data area being deleted.
// 
Procedure OnDeleteDataArea(Val DataArea) Export
	
EndProcedure

// Generates a list of IB parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameters description table.
// Description columns content - see SaaSOperations.GetInfobaseParameterTable().
//
Procedure GetInfobaseParameterTable(Val ParameterTable) Export
	
EndProcedure

// Called before attempting to receive IB parameter values
// from the eponymous constants.
//
// Parameters:
// ParameterNames - Strings array - parameters names values of which should be received.
// If parameter value is generated in this procedure, you
// should delete the name of the processed parameter from array.
// ParameterValues - Structure - parameters values.
//
Procedure OnReceiveInfobaseParameterValues(Val ParameterNames, Val ParameterValues) Export
	
EndProcedure

// Called before attempting to write IB parameter values
// to the constants with the same name.
//
// Parameters:
// ParameterValues - Structure - values of parameters to be set.
// If parameter value is set in this procedure, you
// should delete the corresponding KeyAndValue pair from structure.
//
Procedure OnSetInfobaseParameterValues(Val ParameterValues) Export
	
EndProcedure

// Called if you enable data separation
// by the data areas, during the first configuration start with "InitializeSeparatedIB" parameter ("InitializeSeparatedIB").
// 
// Here you should locate code enabling scheduled jobs that are used only when data separation is enabled and therefore enabling jobs used only when data separation is enabled.
//
Procedure OnEnableSeparationByDataAreas() Export
	
EndProcedure

// Assigns default rights to a user.
// Called during the work in service model if there
// is an update of users rights without administration rights in the service manager.
//
// Parameters:
//  User - CatalogRef.Users - user
//   to set default rights to.
//
Procedure SetDefaultRights(User) Export
	
	
	
EndProcedure

#EndRegion
