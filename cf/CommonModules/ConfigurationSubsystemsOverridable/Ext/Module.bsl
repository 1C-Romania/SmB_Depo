////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Defines the list of modules of libraries
// and the configuration which provide basic information about themselves:
// name, version, the list of update handlers and dependencies on other libraries.
//
// See content of mandatory procedures of
// the module in area ProgramInterface of common module InfobaseUpdateSSL.
//
// Parameters:
//  SubsystemModules - Array - names of server common modules of libraries and the configuration.
//                             For example: BROInformationBaseUpdate - library,
//                                       InformationBasePSUUpdate  - configuration.
//                    
// Note: module of standard subsystems
// library InfobaseUpdateSSL shall not be explicitly added to array SubsystemModules.
//
Procedure OnAddSubsystems(SubsystemModules) Export
	
	SubsystemModules.Add("InfobaseUpdateSTL");
	SubsystemModules.Add("InfobaseUpdateED");
	SubsystemModules.Add("InfobaseUpdateBIP");
	SubsystemModules.Add("InfobaseUpdateSB");
	
EndProcedure

#EndRegion