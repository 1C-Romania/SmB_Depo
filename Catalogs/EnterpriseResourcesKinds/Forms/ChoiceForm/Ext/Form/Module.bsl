
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AllResources = Catalogs.EnterpriseResourcesKinds.AllResources;
	SmallBusinessClientServer.SetListFilterItem(List, "Ref", AllResources, True, DataCompositionComparisonType.NotEqual);
	
EndProcedure // OnCreateAtServer()
