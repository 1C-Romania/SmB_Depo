////////////////////////////////////////////////////////////////////////////////
// The Current ToDos subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns the map of metadata objects and command interface subsystems.
//
// Returns: 
//  The map, where the key is the full object name, and the value - is
//    the array of application command interface subsystems, which this object belongs to.
//
Function ObjectAffiliationToCommandInterfaceSections() Export
	
	ObjectsAndSubsystemsMap = New Map;
	
	For Each Subsystem IN Metadata.Subsystems Do
		If Not Subsystem.IncludeInCommandInterface
			Or Not AccessRight("view", Subsystem)
			Or Not CommonUse.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
			Continue;
		EndIf;
		
		For Each Object IN Subsystem.Content Do
			ObjectSubsystems = ObjectsAndSubsystemsMap[Object.FullName()];
			If ObjectSubsystems = Undefined Then
				ObjectSubsystems = New Array;
			ElsIf ObjectSubsystems.Find(Subsystem) <> Undefined Then
				Continue;
			EndIf;
			ObjectSubsystems.Add(Subsystem);
			ObjectsAndSubsystemsMap.Insert(Object.FullName(), ObjectSubsystems);
		EndDo;
		
		AddSubordinateSubsystemsObjects(Subsystem, ObjectsAndSubsystemsMap);
	EndDo;
	
	Return ObjectsAndSubsystemsMap;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
//
Procedure AddSubordinateSubsystemsObjects(FirstLevelSubsystem, ObjectsAndSubsystemsMap, SubsystemParent = Undefined)
	
	Subsystems = ?(SubsystemParent = Undefined, FirstLevelSubsystem, SubsystemParent);
	
	For Each Subsystem IN Subsystems.Subsystems Do
		If Subsystem.IncludeInCommandInterface
			AND AccessRight("view", Subsystem)
			AND CommonUse.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
			
			For Each Object IN Subsystem.Content Do
				ObjectSubsystems = ObjectsAndSubsystemsMap[Object.FullName()];
				If ObjectSubsystems = Undefined Then
					ObjectSubsystems = New Array;
				ElsIf ObjectSubsystems.Find(FirstLevelSubsystem) <> Undefined Then
					Continue;
				EndIf;
				ObjectSubsystems.Add(FirstLevelSubsystem);
				ObjectsAndSubsystemsMap.Insert(Object.FullName(), ObjectSubsystems);
			EndDo;
			
			AddSubordinateSubsystemsObjects(FirstLevelSubsystem, ObjectsAndSubsystemsMap, Subsystem);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion