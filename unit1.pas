unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, IniFiles, fgl, fpjson, jsonparser;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnLaunch: TButton;
    btnCancel: TButton;
    Edit1: TEdit;
    ImageList2: TImageList;
    ListView2: TListView;

    procedure btnCancelClick(Sender: TObject);
    procedure btnLaunchClick(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure ListView1DblClick(Sender: TObject);
    procedure ListView2KeyPress(Sender: TObject; var Key: char);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

type TBrowserRecord = class
     fName:string;
     fExecutable:string;
     fParameters:string;
     fIconFileName:string;
     fDirToCheck:string;
     ImageIndex: integer;
     end;

     TBrowserList = specialize TFPGObjectList<TBrowserRecord>;

var gBrowserList: TBrowserList;



function ReadConfig(FileName:string; BrowserList:TBrowserList): integer;
var L: TStringList;
    lBrowser:string;
    lBrowserRec: TBrowserRecord;
    lBrowsers: TStringList;
    ConfigText: string;
    i, j: integer;
    jData, jData2 : TJSONData;
    jObject : TJSONObject;
    jArray : TJSONArray;
    jArray2: TJSONArray;
    lExecutable: string;
    lParameters: string;
    lDirToCheck: string;
    lIcon: string;
    s : String;
    lRes: integer;
begin
     result := -1;
     L := TStringList.Create;
     lBrowsers := TStringList.Create;
     try
          try
               L.LoadFromFile(FileName);

          except
               ShowMessage('Config file '+FileName+' does not exist!');
               ExitProcess(1);
          end;
          ConfigText := L.Text;
          jData := GetJSON(ConfigText);
          jObject := TJSONObject(jData);
          jArray := jObject.Arrays['Browsers'];
          for i := 0 to jArray.Count-1 do
          begin
               lBrowsers.Add(jArray.Items[i].AsString);
          end;

          for i := 0 to lBrowsers.Count-1 do
          begin
               lBrowser := lBrowsers.Strings[i];
               jData2 := jData.FindPath(lBrowser);
               lExecutable := jData2.FindPath('Executable').AsString;
               lParameters := jData2.FindPath('Parameters').AsString;
               lDirToCheck := jData2.FindPath('DirToCheck').AsString;
               lIcon := jData2.FindPath('Icon').AsString;


               lBrowserRec := TBrowserRecord.Create();
               lBrowserRec.fName:= lBrowser;
               lBrowserRec.fExecutable:=lExecutable;
               lBrowserRec.fParameters:=lParameters;
               lBrowserRec.fDirToCheck:=lDirToCheck;
               lBrowserRec.fIconFileName:=lIcon;


               gBrowserList.Add(lBrowserRec);
          end;

          result := 0;
     finally
     end;
     lBrowsers.Free;
     L.Free;
end;

function LaunchBrowser(Executable, Parameters, URL, DirToCheck:string):integer;
var lStartupInfo: TSTARTUPINFO;
    lProcessInfo: TPROCESSINFORMATION;
    lExecutable: string;
    lParameters: string;
    lCommandLine: string;
    lLE: integer;
begin
     if length(DirToCheck) > 0 then
     begin
          if DirectoryExists(DirToCheck) then
          begin
          end
          else
          begin
               result := -1;
               ShowMessage('Directory '+DirToCheck+' does not exist!');
               exit;
          end;
     end;
     lExecutable := Trim(Executable);
     lParameters := Trim(Trim(Parameters)+ ' ' + Trim(URL));
     lCommandLine := '"'+lExecutable+'" ' + lParameters;
     FillChar(lStartupInfo, sizeof(lStartupInfo), 0);
     FillChar(lProcessInfo, sizeof(lProcessInfo), 0);
     lStartupInfo.cb:=Sizeof(lStartupInfo);
     CreateProcess(nil, PChar(lCommandLine), nil, nil, false, 0, nil, nil, lStartupInfo, lProcessInfo);
     lLE := GetLastError();
     if lLE <>0 then
          ShowMessage('LastError = '+IntToStr(lLE));
     result := lLE;
end;

function lfLaunch(ListView:TListView; URL:string):integer;
var lBR: TBrowserRecord;
begin
     if ListView.Selected <> nil then
     begin
          lBR := TBrowserRecord(ListView.Selected.Data);
          result := LaunchBrowser(lBR.fExecutable, lBR.fParameters, URL, lBR.fDirToCheck);
     end
     else
          result := -1;
end;

procedure lfQuit;
begin
     ExitProcess(0);
end;

procedure TForm1.FormCreate(Sender: TObject);
var lBr: TBrowserRecord;
    LI: TListItem;
    i: integer;

    bmp:TBitmap;


    inifile: TIniFile;
    lHandle: dword;
    lLE: integer;
    lModuleFileNameBuffer:array[0..1023] of char;
    lExeName, lExeDir, lConfigName: string;

begin
     if ParamCount() >= 1 then
          Edit1.Text := ParamStr(1);

     gBrowserList := TBrowserList.Create();

     lHandle := GetModuleHandle(nil);
     FillChar(lModuleFileNameBuffer, sizeof(lModuleFileNameBuffer), 0);

     GetModuleFileName(lHandle, lModuleFileNameBuffer, sizeof(lModuleFileNameBuffer)-1);
     lExeName := lModuleFileNameBuffer;
     lExeDir := ExtractFileDir(lExeName);
     lConfigName := lExeDir + '\Config.json';

     if ReadConfig(lConfigName, gBrowserList) = 0 then
     begin

          for i := 0 to gBrowserList.Count-1 do
          begin
               bmp := TBitmap.Create();
               bmp.LoadFromFile(gBrowserList.Items[i].fIconFileName);
               gBrowserList.Items[i].ImageIndex := ImageList2.Add(bmp, nil);
          end;

          for i := 0 to gBrowserList.Count-1 do
          begin
               lBr := gBrowserList.Items[i];
               LI := ListView2.Items.Add;
               LI.Caption:= lBr.fName;
               LI.Data:= pointer(lBr);
               LI.ImageIndex:= lBr.ImageIndex;
          end;
     end
     else
     begin
          ShowMessage('Error reading config from '+lConfigName);
          ExitProcess(1);
     end;

end;

procedure TForm1.FormKeyPress(Sender: TObject; var Key: char);
begin
     if Key = #13 then
     begin
          if lfLaunch(ListView2, Edit1.Text) = 0 then
               lfQuit();
     end;

     if Key = #27 then
     begin
          lfQuit();
     end;
end;





procedure TForm1.ListView1DblClick(Sender: TObject);
var i: integer;
begin
     if lfLaunch(ListView2, Edit1.Text) = 0 then
          lfQuit();
end;

procedure TForm1.ListView2KeyPress(Sender: TObject; var Key: char);
begin
     if Key = #13 then
     begin
          if lfLaunch(ListView2, Edit1.Text) = 0 then
               lfQuit();
     end;

     if Key = #27 then
     begin
          lfQuit();
     end;
end;

procedure TForm1.btnLaunchClick(Sender: TObject);
begin
     if lfLaunch(ListView2, Edit1.Text) = 0 then
          lfQuit();
end;

procedure TForm1.Edit1KeyPress(Sender: TObject; var Key: char);
begin
     if Key = #13 then
     begin
          if lfLaunch(ListView2, Edit1.Text) = 0 then
               lfQuit();
     end;

     if Key = #27 then
     begin
          lfQuit();
     end;
end;

procedure TForm1.btnCancelClick(Sender: TObject);
begin
     lfQuit();
end;

end.

