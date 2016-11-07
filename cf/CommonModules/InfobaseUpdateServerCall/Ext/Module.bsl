////////////////////////////////////////////////////////////////////////////////
// IB version update subsystem
// Server procedures and functions of
// the infobase update on configuration version change.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Outdated. You should use the same procedure in the general module InfobaseUpdate.
Function RunInfobaseUpdate() Export
	
	Return InfobaseUpdate.RunInfobaseUpdate();
	
EndFunction

#EndRegion
