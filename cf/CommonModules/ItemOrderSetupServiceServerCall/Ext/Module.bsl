////////////////////////////////////////////////////////////////////////////////
// Subsystem "Items sequence setting".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See this function in the ItemOrderSetupService module.
Function ChangeElementsOrder(Refs, DynamicList, RepresentedAsList, Direction) Export
	
	Return ItemOrderSetupService.ChangeElementsOrder(
		Refs, DynamicList, RepresentedAsList, Direction);
	
EndFunction

#EndRegion
