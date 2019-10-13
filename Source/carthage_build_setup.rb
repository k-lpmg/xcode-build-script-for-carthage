require 'set'
require 'xcodeproj'

class String
    def black;          "\e[30m#{self}\e[0m" end
    def red;            "\e[31m#{self}\e[0m" end
    def green;          "\e[32m#{self}\e[0m" end
    def brown;          "\e[33m#{self}\e[0m" end
    def blue;           "\e[34m#{self}\e[0m" end
    def magenta;        "\e[35m#{self}\e[0m" end
    def cyan;           "\e[36m#{self}\e[0m" end
    def gray;           "\e[37m#{self}\e[0m" end
    
    def bg_black;       "\e[40m#{self}\e[0m" end
    def bg_red;         "\e[41m#{self}\e[0m" end
    def bg_green;       "\e[42m#{self}\e[0m" end
    def bg_brown;       "\e[43m#{self}\e[0m" end
    def bg_blue;        "\e[44m#{self}\e[0m" end
    def bg_magenta;     "\e[45m#{self}\e[0m" end
    def bg_cyan;        "\e[46m#{self}\e[0m" end
    def bg_gray;        "\e[47m#{self}\e[0m" end
    
    def bold;           "\e[1m#{self}\e[22m" end
    def italic;         "\e[3m#{self}\e[23m" end
    def underline;      "\e[4m#{self}\e[24m" end
    def blink;          "\e[5m#{self}\e[25m" end
    def reverse_color;  "\e[7m#{self}\e[27m" end
end

# Constants
@scriptTargets = []
CARTHAGE_FRAMEWORK_PATH = "YOUR_PROJECT_PATH/Carthage/Build/iOS"
CARTHAGE_SCRIPT_NAME = "[CT] Carthage Script"
CARTHAGE_SCRIPT = "/usr/local/bin/carthage copy-frameworks"

# Variables
@project = Xcodeproj::Project.open"YOUR_PROJECT_PATH/*.xcodeproj"

# Methods
def create_carthage_script
    build_phase = @project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
    build_phase.name = CARTHAGE_SCRIPT_NAME
    build_phase.shell_script = CARTHAGE_SCRIPT
    
    input_paths = []
    output_paths = []
    Dir.entries(CARTHAGE_FRAMEWORK_PATH).each do |entry|
        matched = /^(.*)\.framework$/.match(entry)
        if !matched.nil?
            input_paths.push("${SRCROOT}/Carthage/Build/iOS/#{entry}")
            output_paths.push("$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/#{entry}")
        end
    end
    build_phase.input_paths = input_paths
    build_phase.output_paths = output_paths
    return build_phase
end

def update_embed_frameworks
    build_phase = @project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    
    Dir.entries(CARTHAGE_FRAMEWORK_PATH).each do |entry|
        matched = /^(.*)\.framework$/.match(entry)
        if !matched.nil?
            # Remove old frameworks
            @project.frameworks_group.children.each do |child|
                if matched.string == child.name
                    puts "old #{child} removed".gray
                    child.remove_from_project
                end
            end
            
            # Add new frameworks
            frameworks_group = @project.groups.find { |group| group.display_name == 'Frameworks' }
            framework_ref = frameworks_group.new_file("Carthage/Build/iOS/#{matched.string}")
            build_phase.add_file_reference(framework_ref)
            puts "new #{framework_ref} added".cyan
        end
    end
    
end

def carthage_build_phase_setup
    puts "----------------------------------------------------".brown
    puts "💁‍♂️ Start carthage_build_phase_setup".brown
    
    @project.targets.each do |projectTarget|
        isValidateTarget = false
        @scriptTargets.each do |target|
            if target == projectTarget.name
                isValidateTarget = true
            end
        end
        next if isValidateTarget == false
        
        puts "\n🏃‍ Build target -> #{projectTarget.name}".magenta.bold.underline
        
        # Carthage Script in Build Phases
        existing_carthage_script = projectTarget.build_phases.find { |build_phase|
            build_phase.class == Xcodeproj::Project::Object::PBXShellScriptBuildPhase && build_phase.name == CARTHAGE_SCRIPT_NAME
        }
        if !existing_carthage_script.nil?
            existing_carthage_script.remove_from_project
        end
        new_carthage_script = create_carthage_script
        projectTarget.build_phases << new_carthage_script
        
        # Link Frameworks
        update_embed_frameworks
        
        # Build Settings
        @project.build_configurations.each do |config|
            configuration = projectTarget.add_build_configuration('Debug', :debug)
            if config.name == "Release"
                configuration = projectTarget.add_build_configuration('Release', :release)
            end
            settings = configuration.build_settings
            
            search_paths = settings['FRAMEWORK_SEARCH_PATHS']
            path_class = search_paths.class
            if path_class == String
                new_array = Array.new
                new_array.push(search_paths)
                search_paths = new_array
                elsif path_class == NilClass
                search_paths = Array.new
            end
            search_paths_to_add = ['$(inherited)', '$(PROJECT_DIR)/Carthage/Build/iOS']
            search_paths_to_add.each do |path|
                if search_paths.include?(path) == false
                    search_paths.push(path)
                end
            end
            settings['FRAMEWORK_SEARCH_PATHS'] = search_paths
        end
        
    end
    @project.save
    
    puts "\n🙆‍♂️ Finish carthage_build_phase_setup".brown
    puts "----------------------------------------------------".brown
end

carthage_build_phase_setup
