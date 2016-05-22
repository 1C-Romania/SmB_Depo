
////////////////////////////////////////////////////////////////////////////////
// Subsystem "InternetSupport Monitor"
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Overrides permission to use monitor InternetSupport.
// If it is required to prohibit the use of Online support monitor, then the Cancel parameter is to be set to True;
//
// Parameters:
// Cancel - Boolean - True if showing InternetSupport monitor is banned;
// 	False - otherwise;
// 	Value by default - False;
//
// Example:
// If <Expression>
// 	Then Cancel = True;
// EndIf;
//
Procedure UseOnlineSupportMonitor(Cancel) Export
	
	
	
EndProcedure

// Overrides the option to display the Internet Support monitor on start of the application. If the monitor is shown on start of the application, then:
// 1) InternetSupport monitor will be open on start of the application;
// 2) Online support monitor will also display the "Show on start" settings, with the help of which the user can enable or disable the option to show the monitor on start of the application.
//
// Parameters:
// Use - Boolean - True if it is required to show the Internet Support monitor on start of the application.
// 	False - otherwise.
// 	Value by default - False.
//
Procedure UseMonitorDisplayOnWorkStart(Use) Export
	
	Use = False;
	
EndProcedure

#EndRegion