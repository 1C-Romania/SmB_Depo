////////////////////////////////////////////////////////////////////////////////
// Subsystem "Dynamic configuration update control".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Wait handler verifies that infobase was updated dynamically and reports this to the user.
// 
Procedure IdleHandlerOfIBDynamicChangesCheckup() Export
	
	DynamicUpdateConfigurationControlClient.DynamicUpdateCheckWaitHandler();
	
EndProcedure

#EndRegion
