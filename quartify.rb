def next_eight(val)
  if val % 8 == 0
    val
  else
    val + 8 - val % 8
  end
end

def group_pages(pages)
  if pages.empty?
    []
  else
    quarto = pages[0,4] + pages[-4,4]
    [quarto] + group_pages(pages[4...-4])
  end
end

# encodes the orientation and order of pages in the quarto
ORIENTATIONS = [
  [0, :d],
  [7, :d],
  [3, :u],
  [4, :u],
  [6, :d],
  [1, :d],
  [5, :u],
  [2, :u]
]

def layout_quarto(pages)
  ORIENTATIONS.map {|index, orientation|
    [pages[index], orientation]
  }
end

def layouts_for_page_count(count)
  upped = next_eight(count)
  group_pages((0...upped).to_a).map {|quarto_pages|
    layout_quarto(quarto_pages)
  }
end

DENSITY = 300

def ensure_rotation(quarto_layouts)
  quarto_layouts.each do |quarto_layout|
    quarto_layout.each do |page_number, orientation|
      if orientation == :d
        fn = "out-#{page_number}.png"
        if File.exist?(fn)
          system("mogrify -rotate 180 #{fn}")
        end
      end
    end
  end
end

def create_blanks(quarto_layouts)
  dims = page_0_dims
  quarto_layouts.each do |quarto_layout|
    quarto_layout.each do |page_number, _|
      unless File.exist?(page_filename(page_number))
        `convert -size #{dims.join('x')} xc:none #{page_filename(page_number)}`
      end
    end
  end
end

def page_filename(page)
  "out-#{page}.png"
end

def page_0_dims
  dims = `identify out-0.png`.split(' ')[2]
  dims.split('x')
end

def assemble_pdf(quarto_layouts)
  files = quarto_layouts.flatten(1).map {|page_number, _|
    page_filename(page_number)
  }

  system("convert -density #{DENSITY}x#{DENSITY} -units pixelsperinch #{files.join(' ')} out.pdf")
end

def pdfnup
  system("pdfnup --nup 2x2 --paper letter --no-landscape out.pdf")
end

def split_pdfs(path)
  system("convert -density #{DENSITY}x#{DENSITY} -units pixelsperinch #{path} out.png")
end

def reset_tmp
  system("rm -rf tmp")
  Dir.mkdir('tmp')
end

def get_page_count
  Dir.glob("out*.png").count
end

def quartify(relative_path)
  path = File.expand_path(relative_path)
  reset_tmp
  Dir.chdir('tmp') do
    split_pdfs(path)
    quarto_layouts = layouts_for_page_count(get_page_count)
    ensure_rotation(quarto_layouts)
    create_blanks(quarto_layouts)
    assemble_pdf(quarto_layouts)
    pdfnup
  end
end

if __FILE__ == $0
  quartify(ARGV[0])
end
