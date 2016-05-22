
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
 	Result = True;

	ConnectionParameters.Insert("DeviceID", "");

	Output_Parameters = New Array();

	// Check set parameters.
	Interface       = Undefined;
	Port			       = Undefined;
	Speed     	    = Undefined;
	IPAddress     	= Undefined;
	IPPort        	= Undefined;
	Description   	= Undefined;
	
	Parameters.Property("Interface"     	, Interface);
	Parameters.Property("Port"     	 	, Port);
	Parameters.Property("Speed"   	, Speed);
	Parameters.Property("IPAddress"		, IPAddress);
	Parameters.Property("IPPort"      	, IPPort);
	Parameters.Property("Description"	, Description);

	If Interface     = Undefined
	 Or Port     		= Undefined
	 Or Speed      	= Undefined
	 Or IPAddress  	= Undefined
	 Or IPPort 		  = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.'"));

		Result = False;
	EndIf; 	// End: Checks device parameters.
	
	If Result Then
		
		ValueArray = New Array;
		
		If Interface = 0 Then
			ValueArray.Add(0);
			ValueArray.Add(Port);
			ValueArray.Add(Speed);
		Else	
			ValueArray.Add(1);
			ValueArray.Add(IPAddress);
			ValueArray.Add(IPPort);
		EndIf;
		 		     				
		If DriverObject.Connect(ValueArray, ConnectionParameters.DeviceID) Then
			Output_Parameters.Add(""); 
			Output_Parameters.Add(Undefined); 
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1]);
			Result = False;
		EndIf;
		
	EndIf;

	Return Result;
	
EndFunction

// Function disconnects a device.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Try     
		Result = DriverObject.Disable(ConnectionParameters.DeviceID);
	Except
	EndTry;
	
	Result = True;
	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export
     
	Result = True;
	Output_Parameters = New Array();

	// Export products to the scales with labels print.
	If Command = "ExportProducts" Then
		Products 				= InputParameters[0];
		PartialExport 	= InputParameters[1];
		Result = ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters);
											  
	// Clear the base of scales with printing labels.
	ElsIf Command = "ClearBase" Then
		Result = ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Test device
	ElsIf Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	
	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);
		Result = False;

	EndIf;

	Return Result;

EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions
                                                          
// Function exports the products table to the scales with labels printing.
//
Function ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters) 
	
	Result = True;
	
	If Products.Count() = 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='There is no data to export.'"));
		Return False;
	EndIf;

	CurrentPercent = 0;
	Status(NStr("en='Exporting products...'"), CurrentPercent);	
	
	If Not PartialExport Then		
		If Not DriverObject.ClearProducts(ConnectionParameters.DeviceID) Then	
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1]);
			Result = False;
			Return Result;
		EndIf;
	EndIf;
	
	PercentIncrement = 100 / Products.Count();

	For Iterator = 0 To Products.Count() - 1 Do
		
		Selection = New Structure;

		If Products[Iterator].Property("PLU") Then
			Selection.Insert("PLU", Products[Iterator].PLU); 
		EndIf;
		
		If Products[Iterator].Property("Code") Then
			Selection.Insert("Code", Products[Iterator].Code); 
		EndIf;
		
		TempName = Left(Products[Iterator].Description, 40); 
		
		If Products[Iterator].Property("DescriptionFull") AND 
			Not IsBlankString(Products[Iterator].Property("DescriptionFull")) Then
			TempName = Left(Products[Iterator].DescriptionFull, 40);
		EndIf;
		Selection.Insert("Name", TempName);
		
		If Products[Iterator].Property("Price") Then
			Selection.Insert("Price", Products[Iterator].Price); 
		EndIf;
		
		If Products[Iterator].Property("ProductDescription") Then
			Selection.Insert("Description", Products[Iterator].ProductDescription); 
		Else
			Selection.Insert("Description", ""); 
		EndIf;
		
		If Products[Iterator].Property("StoragePeriod") Then
			Selection.Insert("ShelfTime", Products[Iterator].StoragePeriod); 
		Else
			Selection.Insert("ShelfTime", 7); 
		EndIf;
		
		If DriverObject.ExportProducts(ConnectionParameters.DeviceID, Selection) Then
			Output_Parameters.Add(""); 
			Output_Parameters.Add(Undefined); 
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1]);
			Result = False;
			Return Result;
		EndIf;
		
		CurrentPercent = CurrentPercent + PercentIncrement;
        Status(NStr("en='Exporting products...'"), Round(CurrentPercent));	

	EndDo;
	
	Return Result;

EndFunction

// The function clears the products table to the scales with labels printing.
//
Function ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 

	Result = True;  
	
	Status(NStr("en = 'The products are being cleared in the scales with labels printing...'"));
	
	If Not DriverObject.ClearProducts(ConnectionParameters.DeviceID) Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.GetError(Output_Parameters[1]);
		Result = False;
	EndIf;
		
	Return Result;

EndFunction

// Function tests the device.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 
	
	Result = True;            
	TestResult = "";

	ValueArray = New Array;

	If Parameters.Interface = 0 Then
		ValueArray.Add(0);
		ValueArray.Add(Parameters.Port);
		ValueArray.Add(Parameters.Speed);
	Else
		ValueArray.Add(1);
		ValueArray.Add(Parameters.IPAddress);
		ValueArray.Add(Parameters.IPPort);
	EndIf;

	Result = DriverObject.DeviceTest(ValueArray, TestResult);

	Output_Parameters.Add(?(Result, 0, 999));
	Output_Parameters.Add(TestResult);

	Return Result;
		
EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;

	Output_Parameters.Add(NStr("en='Installed'"));
	Output_Parameters.Add(NStr("en='Not defined'"));

	Try                                     
		Output_Parameters[1] = DriverObject.GetVersionNumber();
	Except
	EndTry;

	Return Result;   

EndFunction

#EndRegion
