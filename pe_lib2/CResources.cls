VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CResources"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
'do not hang onto a ref of this class and reload the pe editor with something else

'the paths this returns arent quite right yet... :(

'example paths: \ICON\30001\0
'               \VERSION\1\1033

Private parent As CPEEditor

Public rva As Long
Public fileOffset As Long
Public Size As Long
Public hadRecursive As Boolean

Dim hFile As Long

Public Entries As New Collection 'of final collected CResData with flat path..
Private RootDir As New CResDir

Friend Property Get pe() As CPEEditor
    Set pe = parent
End Property

Friend Property Get fhandle() As Long
    fhandle = hFile
End Property

Function dumpNames(Optional includeSize As Boolean = True) As Collection
    On Error Resume Next
    Dim c As New Collection
    Dim e As CResData

    Set dumpNames = c

    For Each e In Entries
        If includeSize Then
            c.Add rpad(e.Size, 8) & e.path
        Else
            c.Add e.path
        End If
    Next

End Function

Friend Sub LoadSelf(owner As CPEEditor)
    
    Set parent = owner
        
    rva = owner.OptionalHeader.ddVirtualAddress(Resource_Table)
    Size = owner.OptionalHeader.ddSize(Resource_Table)
    fileOffset = owner.RvaToOffset(rva)
    
    If rva = 0 Or Size = 0 Or fileOffset = 0 Then Exit Sub
    fileOffset = fileOffset + 1
    
    hFile = FreeFile
    Open owner.LoadedFile For Binary Access Read As #hFile
    
    'this will walk the directory/sub directories and entries tree and record the path as it goes.
    'when it finally gets to an actual data entry..the data will be added to our entries collection of CResData
    'we use the simplified path to references the resources so clients dont have to walk the tree themselves..
    'CresDir and CResEntry do not need to be used publically by clients...
    RootDir.LoadDir Me, fileOffset
    
    Close hFile


End Sub

Private Sub DumpFile(hFile As Long, offset As Long, Optional Size As Long = 16)
    Dim curPos As Long
    Dim b() As Byte
    ReDim b(1 To Size)
    
    curPos = Seek(hFile)
    Get hFile, offset, b()
    Seek hFile, curPos
    
    Debug.Print Right("00000000" & Hex(offset), 8) & HexDump(StrConv(b, vbUnicode))
    
End Sub

Public Function GetResource(path As String, ByRef outRetVal As CResData) As Boolean
    Set outRetVal = Nothing
    For Each outRetVal In Entries
        If LCase(outRetVal.path) = LCase(path) Then
            GetResource = True
            Exit Function
        End If
    Next
    Set outRetVal = Nothing
End Function

Public Function GetResourceData(path As String, ByRef bArray) As Boolean
    Dim cre As CResData
    Dim f As Long
    Dim b() As Byte
    Dim fOffset As Long
    
    Erase bArray
    If Not FileExists(parent.LoadedFile) Then Exit Function
    If Not GetResource(path, cre) Then Exit Function
    
    fOffset = parent.RvaToOffset(cre.OffsetToDataRVA)
    If cre.Size = 0 Or cre.OffsetToDataRVA = 0 Or fOffset = 0 Then Exit Function
    
    ReDim b(cre.Size - 1)
    f = FreeFile
    Open parent.LoadedFile For Binary As f
    Get f, fOffset + 1, b
    Close f
    
    bArray = b()
    GetResourceData = True
    
End Function

Public Function SaveResource(filePath As String, resPath As String) As Boolean
    Dim b() As Byte, f As Long
    If FileExists(filePath) Then Kill filePath
    If Not GetResourceData(resPath, b) Then Exit Function
    
    f = FreeFile
    Open filePath For Binary As f
    Put f, , b()
    Close f
    
    If FileLen(filePath) = UBound(b) + 1 Then SaveResource = True
End Function
