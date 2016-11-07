////////////////////////////////////////////////////////////////////////////////
// Work with compatibility table of additional reports and data processors
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// It reads the compatibility table of the
//  supplied additional data processors and configurations with the versions
//
// Parameters:
//  TableOfCompatibility - XDTODataObject {http://www.1c.ru/1cFresh/ApplicationExtensions/Compatibility/1.0.0.1}CompatibilityList.
//
// Returns:
//  Values tables, columns:
//    ConfigarationName - String, configuration name, 
//    VersionNumber - String, configuration version.
//
Function ReadCompatibilityTable(Val TableOfCompatibility) Export
	
	Result = New ValueTable();
	Result.Columns.Add("ConfigarationName", New TypeDescription("String"));
	Result.Columns.Add("VersionNumber", New TypeDescription("String"));
	
	For Each CompatibilityObject IN TableOfCompatibility.CompatibilityObjects Do
		
		String = Result.Add();
		FillPropertyValues(String, CompatibilityObject);
		
	EndDo;
	
	Return Result;
	
EndFunction