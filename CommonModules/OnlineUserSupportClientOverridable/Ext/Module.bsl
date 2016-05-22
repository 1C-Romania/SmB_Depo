
////////////////////////////////////////////////////////////////////////////////
// The "Online User Support" subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Overrides Web page opening in the
// configuration if the configuration provides for own mechanisms for opening Web pages.
// If the configuration does not use own
// mechanisms for Web pages opening, then you should
// leave the procedure body empty, otherwise,
// you have to set the False value for the StandardDataProcessor parameter.
//
// Parameters:
// PageAddress - String - URL-address of the Web page being opened;
// WindowTitle - String - window title where
// 	the Web page is displayed,
// 	if an internal configuration form is used for opening the Web page;
// StandardDataProcessor - Boolean - a flag showing
// 	that it is required to open the Online support page using a standard method is returned to the parameter.
// 	Value by default - Truth.
//
Procedure OpenInternetPage(PageAddress, WindowTitle, StandardDataProcessor) Export
	
	
	
EndProcedure

#EndRegion
