# coding: utf-8

############################################################
# sarファイルからCPU使用率とメモリ使用率を取得する。
############################################################

require 'time'
require "csv"
require 'rubygems'
require 'spreadsheet'
require 'fileutils'

########################################
# 変更パラメータ
########################################

if ARGV.size != 7
	p "引数の数が違います 誤：" + ARGV.size.to_s + " 正：7"
	exit 1
end

## ディレクトリ、ファイル名のための設定
targetVersion = ARGV[0]

# 1回の試験で何回同じスレッドを実行しているか
runtimes = ARGV[1].to_i

# 1回の試験の実行時間（秒）
$jmeter_duration = ARGV[2].to_i

# warmupとして試験対象外にする時間
$warmUpSeconds = ARGV[3].to_i

# warmdownとして試験対象外にする時間
$warmDownSeconds = ARGV[4].to_i

# スレッド数（カンマ区切りで複数可）
threadTerm = ARGV[5]

# 試験結果のあるディレクトリ
daseDirName = ARGV[6]

graphDir = "graph/"
# ディレクトリが無かったら作る
FileUtils.mkdir_p(daseDirName + graphDir) unless FileTest.exist?(daseDirName + graphDir)

## プレーンファイルに結果ファイルを吐く場合 start
# ディレクトリが無かったら作る
#resultDir = "result/"
#FileUtils.mkdir_p(daseDirName + resultDir) unless FileTest.exist?(daseDirName + resultDir)
## プレーンファイルに結果ファイルを吐く場合 end

serverDirs = [ targetVersion + "_CL/", targetVersion + "_AP/", targetVersion + "_DB/" ]

targetServers = [ "jmeterserver", "apserver", "dbserver" ]

resultExcel = "material_multi_" + threadTerm + "_CPU_MEMORY_" + targetVersion + ".xls"

## プログラムで処理するための設定

# スレッドの設定
threads = ARGV[5].split(",")

########################################
# 関数定義
########################################

## 5分間捨てるために時間を計算
# 文字列の日付をTime型に変換
def funcChangeExecuteTimeStrToTime(exexuteJapTime,updateDay)

	# 時を取得
	sepHour = exexuteJapTime[0,2]

	# 分を取得
	sepMin = exexuteJapTime[3,2]

	# 秒を取得
	sepSec = exexuteJapTime[6,2]

	## 日時は適当
	sepYear = 2000
	sepMonth = 1
	sepDay = updateDay

	exexuteTime = Time.local(sepYear , sepMonth , sepDay , sepHour , sepMin, sepSec )

	return exexuteTime
	
end

## 先頭5分間のWarm-Up時間を計算
def calcWarmUpTime(exexuteTime)

	warmUpTime = exexuteTime + $warmUpSeconds

	return warmUpTime
	
end

## 最後5分間のWarm-Up時間を計算
def calcWarmDownTime(exexuteTime)

	warmDownTime = exexuteTime + ($jmeter_duration - $warmDownSeconds )

	return warmDownTime
	
end

# 配列-分析
class Array
	# 平均値
	def average
		inject(0.0) { |sum, i| sum += i } / size
	end
end

#############################
# main処理
#############################

Spreadsheet.client_encoding = 'UTF-8'

excelBook = Spreadsheet::Workbook.new

excelCpuSumSheet = excelBook.create_worksheet
excelCpuSumSheet.name = "CPUまとめ"

excelCpuSumSheet[1,1] = "スレッド数"
excelCpuSumSheet[1,2] = "CLサーバ CPU使用率(%)"
excelCpuSumSheet[1,3] = "%usr"
excelCpuSumSheet[1,4] = "%sys"
excelCpuSumSheet[1,5] = "%iowait"
excelCpuSumSheet[1,6] = "APサーバ CPU使用率(%)"
excelCpuSumSheet[1,7] = "%usr"
excelCpuSumSheet[1,8] = "%sys"
excelCpuSumSheet[1,9] = "%iowait"
excelCpuSumSheet[1,10] = "DBサーバ CPU使用率(%)"
excelCpuSumSheet[1,11] = "%usr"
excelCpuSumSheet[1,12] = "%sys"
excelCpuSumSheet[1,13] = "%iowait"

excelMemorySumSheet = excelBook.create_worksheet
excelMemorySumSheet.name = "Memoryまとめ"

excelMemorySumSheet[1,1] = "スレッド数"
excelMemorySumSheet[1,2] = "CLメモリー使用率"
excelMemorySumSheet[1,3] = "APメモリー使用率"
excelMemorySumSheet[1,4] = "DBメモリー使用率"

p "========== sarの結果ファイルから必要データを取得 ==========" 

server_cnt=0
$targetTime = Time.now

targetServers.each { | targetServer |

	thread_cnt = 0

	# スレッド数の文繰り返す
	threads.each { | threadNum|
		
		cpuUsrAry = []
		cpuNiceAry = []
		cpuIowaitAry = []
		cpuSumAry = []
		
		memorySumAry = []
		
		excelCpuValueSheet = excelBook.create_worksheet
		excelCpuValueSheet.name = targetServer + "_CPU_" + threadNum.to_s + "スレッド"
		
		excelCpuValueSheet[1,1] = "時間"
		excelCpuValueSheet[1,2] = "CPU使用率(%)"
		excelCpuValueSheet[1,3] = "%usr"
		excelCpuValueSheet[1,4] = "%sys"
		excelCpuValueSheet[1,5] = "%iowait"
		
		excelCpuValueSheetRow=2
		
		excelMemoryValueSheet = excelBook.create_worksheet
		excelMemoryValueSheet.name = targetServer + "_MEM_" + threadNum.to_s + "スレッド"
		
		excelMemoryValueSheet[1,1] = "時間"
		excelMemoryValueSheet[1,2] = "メモリー使用率"
		
		excelMemoryValueSheetRow=2
		
## プレーンファイルに結果ファイルを吐く場合 start
#		resultCpuFile = "sar_cpu_" + threadNum.to_s + "_" + targetServer + "_all.log"
#		result_cpu_file = File.open( daseDirName + resultDir + resultCpuFile , "w")
#		resultMemoryFile = "sar_memory_" + threadNum.to_s + "_" + targetServer + "_all.log"
#		result_memory_file = File.open( daseDirName + resultDir + resultMemoryFile , "w")
## プレーンファイルに結果ファイルを吐く場合 end
	
		for exexuteNum in 1..runtimes do
			
			targetDir = daseDirName + serverDirs[server_cnt] + "atrs_" + threadNum.to_s + "_" + exexuteNum.to_s + "_" + targetServer + "/"
			
			targetFile = "sar.rpt"
			
			reader = File.open( targetDir + targetFile , "r:utf-8")
			
			cpuFlg = 0
			memoryFlg = 0
			$updateCpuDay=1
			$updateMemoryDay=1
			
			reader.each do |row|
			
				#	ログの行を分割
				rowSepAry = row.split(" ")
				
				# 空行は読み飛ばす
				if rowSepAry[0] == nil then
					next
				end

				# CPU分
				if cpuFlg == 0 then
					if rowSepAry[1] == "CPU" then
						cpuFlg = 1
					end
					next
				end
				
				if cpuFlg == 1 then
					exexuteTime = funcChangeExecuteTimeStrToTime(rowSepAry[0], $updateCpuDay)
					$beforeCpuExexuteTime = exexuteTime
					$warmUpTime = calcWarmUpTime(exexuteTime)
					$warmDownTime = calcWarmDownTime(exexuteTime)
					firstFlg = false
					cpuFlg = 2
				end
				
				if cpuFlg == 2 then
					if rowSepAry[0] == "平均値:" then
						cpuFlg = 3
						next
					end
					$exexuteTime = funcChangeExecuteTimeStrToTime(rowSepAry[0], $updateCpuDay)
					
					# 日跨りを計算
					if $exexuteTime < $beforeCpuExexuteTime then
						$beforeCpuExexuteTime=$exexuteTime + (86400 * $updateCpuDay)
						$updateCpuDay=$updateCpuDay+1
						$exexuteTime=$beforeCpuExexuteTime
					end
					
					if rowSepAry[1] == "all" && $exexuteTime > $warmUpTime && $exexuteTime < $warmDownTime then
						## プレーンファイルに吐く場合
						#result_cpu_file.puts( rowSepAry.join("\t") )
						# 集計結果用確保
						cpuUsrAry.push(rowSepAry[2].to_f)
						cpuNiceAry.push(rowSepAry[3].to_f)
						cpuIowaitAry.push(rowSepAry[5].to_f)
						cpuSumAry.push(rowSepAry[2].to_f + rowSepAry[3].to_f + rowSepAry[5].to_f)
						# 個別結果シートに出力
						excelCpuValueSheet[excelCpuValueSheetRow,1] = rowSepAry[0]
						excelCpuValueSheet[excelCpuValueSheetRow,2] = rowSepAry[2].to_f + rowSepAry[3].to_f + rowSepAry[5].to_f
						excelCpuValueSheet[excelCpuValueSheetRow,3] = rowSepAry[2]
						excelCpuValueSheet[excelCpuValueSheetRow,4] = rowSepAry[3]
						excelCpuValueSheet[excelCpuValueSheetRow,5] = rowSepAry[5]
						excelCpuValueSheetRow = excelCpuValueSheetRow + 1
					end
				end
				
				# メモリ分
				if memoryFlg == 0 then
					if rowSepAry[1] == "kbmemfree" then
						memoryFlg = 1
					end
					next
				end
				
				if memoryFlg == 1 then
					exexuteTime = funcChangeExecuteTimeStrToTime(rowSepAry[0], $updateMemoryDay)
					$beforeMemoryExexuteTime = exexuteTime
					$warmUpTime = calcWarmUpTime(exexuteTime)
					$warmDownTime = calcWarmDownTime(exexuteTime)
					firstFlg = false
					memoryFlg = 2
				end
				
				if memoryFlg == 2 then
					if rowSepAry[0] == "平均値:" then
						memoryFlg = 3
						next
					end
					$exexuteTime = funcChangeExecuteTimeStrToTime(rowSepAry[0], $updateMemoryDay)

					# 日跨りを計算
					if $exexuteTime < $beforeMemoryExexuteTime then
						$beforeMemoryExexuteTime=$exexuteTime + (86400 * $updateMemoryDay)
						$updateMemoryDay=$updateMemoryDay+1
						$exexuteTime=$beforeMemoryExexuteTime
					end

					if $exexuteTime > $warmUpTime && $exexuteTime < $warmDownTime then
						## プレーンファイルに吐く場合
						#result_memory_file.puts( rowSepAry.join("\t") )
						# 集計結果用確保
						memorySum = (rowSepAry[2].to_f - (rowSepAry[4].to_f + rowSepAry[5].to_f)) / (rowSepAry[1].to_f + rowSepAry[2].to_f) * 100
						memorySumAry.push(memorySum)
						# 個別結果シートに出力
						excelMemoryValueSheet[excelMemoryValueSheetRow,1] = rowSepAry[0]
						excelMemoryValueSheet[excelMemoryValueSheetRow,2] = memorySum
						excelMemoryValueSheetRow = excelMemoryValueSheetRow + 1
					end
				end
			end
			reader.close()
		end
		
		if targetServer == "jmeterserver"
			excelCpuSumSheet[thread_cnt+2,1] = threadNum
			excelCpuSumSheet[thread_cnt+2,2] = cpuSumAry.average
			excelCpuSumSheet[thread_cnt+2,3] = cpuUsrAry.average
			excelCpuSumSheet[thread_cnt+2,4] = cpuNiceAry.average
			excelCpuSumSheet[thread_cnt+2,5] = cpuIowaitAry.average
			excelMemorySumSheet[thread_cnt+2,1] = threadNum
			excelMemorySumSheet[thread_cnt+2,2] = memorySumAry.average
		elsif targetServer == "apserver"
			excelCpuSumSheet[thread_cnt+2,6] = cpuSumAry.average
			excelCpuSumSheet[thread_cnt+2,7] = cpuUsrAry.average
			excelCpuSumSheet[thread_cnt+2,8] = cpuNiceAry.average
			excelCpuSumSheet[thread_cnt+2,9] = cpuIowaitAry.average
			excelMemorySumSheet[thread_cnt+2,3] = memorySumAry.average
		elsif targetServer == "dbserver"
			excelCpuSumSheet[thread_cnt+2,10] = cpuSumAry.average
			excelCpuSumSheet[thread_cnt+2,11] = cpuUsrAry.average
			excelCpuSumSheet[thread_cnt+2,12] = cpuNiceAry.average
			excelCpuSumSheet[thread_cnt+2,13] = cpuIowaitAry.average
			excelMemorySumSheet[thread_cnt+2,4] = memorySumAry.average
		end
		
		thread_cnt = thread_cnt + 1
		
		excelBook.write(daseDirName + graphDir + resultExcel)
		
		## プレーンファイルに吐く場合
		#result_cpu_file.close()
		#result_memory_file.close()
	}
	server_cnt = server_cnt + 1

}

